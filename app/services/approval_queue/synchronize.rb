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
        reconcile_open_requests
        profile_ids = user.relationship_profiles.kept.select(:id)
        queue_extracted_memories(profile_ids)
        queue_high_impact_memories(profile_ids)
      end
    end

    private

    attr_reader :user

    def queue_extracted_memories(profile_ids)
      scope = ExtractedMemory.where(relationship_profile_id: profile_ids, status: "pending")
      without_current_snapshot(scope, subject_type: "ExtractedMemory", action_key: "review_extracted_memory")
        .limit(SOURCE_LIMIT)
        .each do |subject|
        enqueue(subject:, action_key: "review_extracted_memory")
      end
    end

    def queue_high_impact_memories(profile_ids)
      scope = MemoryRecord
        .where(relationship_profile_id: profile_ids, high_impact_automation_approved_at: nil)
        .where.not(status: "archived")
        .unprotected
        .where("source = 'ai_inferred' OR confidence IN ('low', 'inferred')")

      without_current_snapshot(scope, subject_type: "MemoryRecord", action_key: "approve_high_impact_memory")
        .limit(SOURCE_LIMIT)
        .each do |subject|
          enqueue(subject:, action_key: "approve_high_impact_memory")
        end
    end

    def enqueue(subject:, action_key:)
      with_subject_lock(subject) do
        return unless Eligibility.eligible?(subject, action_key:)

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

    def reconcile_open_requests
      requests_requiring_reconciliation.each do |request|
        subject = request.subject
        with_subject_lock(subject) do
          request.lock!
          if Eligibility.eligible?(subject, action_key: request.action_key)
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

    def with_subject_lock(subject)
      profile = subject.relationship_profile
      profile.with_lock do
        subject.lock!
        yield
      end
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
              AND approval_requests.subject_updated_at = #{table_name}.updated_at
          )
        SQL
        subject_type,
        action_key
      )
    end

    def terminal_request_still_applies?(subject:, action_key:)
      request = user.approval_requests.completed.where(subject:, action_key:).first

      request.present? && request.subject_updated_at == subject.updated_at
    end
  end
end
