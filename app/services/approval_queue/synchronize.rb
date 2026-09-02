module ApprovalQueue
  class Synchronize
    SOURCE_LIMIT = 100
    REQUEST_LIMIT = 100

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      user.with_lock("FOR NO KEY UPDATE") do
        profile_ids = user.relationship_profiles.kept.select(:id)
        requests = discard_orphaned_requests(requests_requiring_reconciliation.to_a)
        extracted_memories = extracted_memory_candidates(profile_ids).to_a
        high_impact_memories = high_impact_memory_candidates(profile_ids).to_a
        subjects = requests.filter_map(&:subject) + extracted_memories + high_impact_memories

        with_ordered_profile_locks(subjects) do
          protected_memory_ids = load_protected_memory_ids(subjects)
          reconcile_open_requests(requests, profile_locked: true, protected_memory_ids:)
          queue_extracted_memories(extracted_memories, profile_locked: true, protected_memory_ids:)
          queue_high_impact_memories(high_impact_memories, profile_locked: true, protected_memory_ids:)
        end
      end
    end

    private

    attr_reader :user

    def extracted_memory_candidates(profile_ids)
      scope = ExtractedMemory.where(relationship_profile_id: profile_ids, status: "pending")
      without_current_snapshot(scope, subject_type: "ExtractedMemory", action_key: "review_extracted_memory")
        .order(:created_at, :id)
        .limit(SOURCE_LIMIT)
    end

    def queue_extracted_memories(subjects, profile_locked: false, protected_memory_ids: nil)
      subjects.each do |subject|
        enqueue(subject:, action_key: "review_extracted_memory", profile_locked:, protected_memory_ids:)
      end
    end

    def high_impact_memory_candidates(profile_ids)
      scope = MemoryRecord
        .where(relationship_profile_id: profile_ids, high_impact_automation_approved_at: nil)
        .where.not(status: "archived")
        .unprotected
        .where("source = 'ai_inferred' OR confidence IN ('low', 'inferred')")

      without_current_snapshot(scope, subject_type: "MemoryRecord", action_key: "approve_high_impact_memory")
        .order(:created_at, :id)
        .limit(SOURCE_LIMIT)
    end

    def queue_high_impact_memories(subjects, profile_locked: false, protected_memory_ids: nil)
      subjects.each do |subject|
        enqueue(subject:, action_key: "approve_high_impact_memory", profile_locked:, protected_memory_ids:)
      end
    end

    def enqueue(subject:, action_key:, profile_locked: false, protected_memory_ids: nil)
      with_subject_lock(subject, profile_locked:) do
        return unless Eligibility.eligible?(subject, action_key:, protected_memory_ids:)

        kind = Eligibility.kind(subject)
        risk_level = Eligibility.risk_level(subject, action_key:)
        confidence = subject.confidence
        open_request = user.approval_requests.open.find_by(subject:, action_key:)
        return refresh_open_request(open_request, subject:, risk_level:, confidence:) if open_request
        return if terminal_request_still_applies?(subject:, action_key:)

        user.approval_requests.create!(
          subject:,
          kind:,
          action_key:,
          risk_level:,
          confidence:,
          subject_updated_at: subject.updated_at
        )
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordNotUnique
      nil
    end

    def reconcile_open_requests(requests, profile_locked: false, protected_memory_ids: nil)
      requests.each do |request|
        subject = request.subject
        with_subject_lock(subject, profile_locked:) do
          request.lock!
          if Eligibility.eligible?(subject, action_key: request.action_key, protected_memory_ids:)
            refresh_open_request(
              request,
              subject:,
              risk_level: Eligibility.risk_level(subject, action_key: request.action_key),
              confidence: subject.confidence
            )
          else
            request.update!(status: "superseded", decided_at: Time.current, deferred_until: nil)
          end
        end
      rescue ActiveRecord::RecordNotFound
        next
      end
    end

    def discard_orphaned_requests(requests)
      requests.reject do |request|
        next false if request.subject

        request.destroy!
        true
      rescue ActiveRecord::RecordNotFound
        true
      end
    end

    def requests_requiring_reconciliation
      user.approval_requests.open
        .where(<<~SQL.squish)
          NOT (
            (
              approval_requests.subject_type = 'ExtractedMemory'
              AND approval_requests.action_key = 'review_extracted_memory'
              AND EXISTS (
                SELECT 1
                FROM extracted_memories
                INNER JOIN relationship_profiles
                  ON relationship_profiles.id = extracted_memories.relationship_profile_id
                WHERE extracted_memories.id = approval_requests.subject_id
                  AND extracted_memories.status = 'pending'
                  AND relationship_profiles.discarded_at IS NULL
              )
            )
            OR
            (
              approval_requests.subject_type = 'MemoryRecord'
              AND approval_requests.action_key = 'approve_high_impact_memory'
              AND EXISTS (
                SELECT 1
                FROM memory_records
                INNER JOIN relationship_profiles
                  ON relationship_profiles.id = memory_records.relationship_profile_id
                WHERE memory_records.id = approval_requests.subject_id
                  AND memory_records.high_impact_automation_approved_at IS NULL
                  AND memory_records.status != 'archived'
                  AND (memory_records.source = 'ai_inferred' OR memory_records.confidence IN ('low', 'inferred'))
                  AND relationship_profiles.discarded_at IS NULL
                  AND NOT EXISTS (
                    SELECT 1
                    FROM privacy_vault_items
                    WHERE privacy_vault_items.protectable_type = 'MemoryRecord'
                      AND privacy_vault_items.protectable_id = memory_records.id
                  )
              )
            )
          )
        SQL
        .includes(:subject)
        .order(:created_at, :id)
        .limit(REQUEST_LIMIT)
    end

    def refresh_open_request(request, subject:, risk_level:, confidence:)
      return request if request.subject_updated_at == subject.updated_at

      request.update!(
        status: "pending",
        risk_level:,
        confidence:,
        subject_updated_at: subject.updated_at,
        deferred_until: nil,
        decided_at: nil
      )
      request
    end

    def with_subject_lock(subject, profile_locked: false)
      profile = subject.relationship_profile
      if profile_locked
        lock_subject_with_profile(subject, profile)
        return yield
      end

      profile.with_lock do
        lock_subject_with_profile(subject, profile)
        yield
      end
    end

    def lock_subject_with_profile(subject, profile)
      subject.lock!
      subject.association(:relationship_profile).target = profile
    end

    def with_ordered_profile_locks(subjects, &block)
      profiles = preload_ordered_profiles(subjects)

      with_profile_locks(profiles, &block)
    end

    def load_protected_memory_ids(subjects)
      memory_ids = subjects.grep(MemoryRecord).map(&:id).uniq
      return {} if memory_ids.empty?

      PrivacyVaultItem
        .where(protectable_type: "MemoryRecord", protectable_id: memory_ids)
        .pluck(:protectable_id)
        .index_with(true)
    end

    def preload_ordered_profiles(subjects)
      profile_ids = subjects.filter_map(&:relationship_profile_id).uniq.sort
      profiles_by_id = RelationshipProfile.where(id: profile_ids).index_by(&:id)

      subjects.each do |subject|
        profile = profiles_by_id[subject.relationship_profile_id]
        subject.association(:relationship_profile).target = profile if profile
      end

      profile_ids.filter_map { |profile_id| profiles_by_id[profile_id] }
    end

    def with_profile_locks(profiles, index = 0, &block)
      profile = profiles[index]
      return block.call unless profile

      profile.with_lock { with_profile_locks(profiles, index + 1, &block) }
    end

    def without_current_snapshot(scope, subject_type:, action_key:)
      table_name = scope.model.table_name
      scope.where(
        <<~SQL.squish,
          NOT EXISTS (
            SELECT 1
            FROM approval_requests
            WHERE approval_requests.subject_type = ?
              AND approval_requests.subject_id = #{table_name}.id
              AND approval_requests.action_key = ?
              AND approval_requests.status != 'superseded'
              AND approval_requests.subject_updated_at = #{table_name}.updated_at
          )
        SQL
        subject_type,
        action_key
      )
    end

    def terminal_request_still_applies?(subject:, action_key:)
      request = user.approval_requests.where(
        subject:,
        action_key:,
        status: %w[approved rejected dismissed]
      ).order(decided_at: :desc, id: :desc).first

      request.present? && request.subject_updated_at == subject.updated_at
    end
  end
end
