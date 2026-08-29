module MemoryExtractions
  class Review
    DECISIONS = %w[approve reject correct].freeze

    def self.call(
      extracted_memory:,
      reviewer:,
      decision:,
      corrected_title: nil,
      corrected_body: nil,
      approval_request: nil,
      expected_lock_version: nil
    )
      new(
        extracted_memory:,
        reviewer:,
        decision: decision.to_s,
        corrected_title:,
        corrected_body:,
        approval_request:,
        expected_lock_version:
      ).call
    end

    def initialize(extracted_memory:, reviewer:, decision:, corrected_title:, corrected_body:, approval_request:, expected_lock_version:)
      @extracted_memory = extracted_memory
      @reviewer = reviewer
      @decision = decision
      @corrected_title = corrected_title
      @corrected_body = corrected_body
      @approval_request = approval_request
      @expected_lock_version = expected_lock_version
    end

    def call
      authorize!
      raise ArgumentError, "Unsupported review decision" unless decision.in?(DECISIONS)

      ApplicationRecord.transaction do
        extracted_memory.relationship_profile.with_lock do
          extracted_memory.lock!
          @queue_request = lock_queue_request
          return extracted_memory unless extracted_memory.pending?

          apply_decision
          complete_recap_if_reviewed
          finalize_queue_request! if queue_request
          extracted_memory
        end
      end
    end

    private

    attr_reader :extracted_memory, :reviewer, :decision, :corrected_title, :corrected_body,
      :approval_request, :expected_lock_version, :queue_request

    def authorize!
      return if reviewer.present? && extracted_memory.relationship_profile.user_id == reviewer.id

      raise Pundit::NotAuthorizedError, "not allowed to review this extracted memory"
    end

    def apply_decision
      case decision
      when "approve" then approve
      when "reject" then reject
      when "correct" then correct
      end
    end

    def lock_queue_request
      request = approval_request || extracted_memory.approval_requests.open.find_by(action_key: "review_extracted_memory")
      return unless request

      unless request.user_id == reviewer.id && request.subject == extracted_memory
        raise Pundit::NotAuthorizedError, "not allowed to decide this approval"
      end

      request.lock!
      if expected_lock_version.present? && request.lock_version != Integer(expected_lock_version)
        raise ActiveRecord::StaleObjectError.new(request, "update")
      end
      request
    end

    def approve
      memory_record = create_memory_record(
        title: extracted_memory.title,
        body: extracted_memory.body,
        source: "ai_inferred",
        confidence: extracted_memory.confidence
      )
      extracted_memory.update!(review_attributes(status: "approved", canonical_memory_record: memory_record))
      record_approval("approved")
    end

    def reject
      extracted_memory.update!(review_attributes(status: "rejected"))
    end

    def correct
      extracted_memory.assign_attributes(corrected_title:, corrected_body:)
      if extracted_memory.corrected_title.blank? || extracted_memory.corrected_body.blank?
        raise ActiveRecord::RecordInvalid, extracted_memory
      end

      memory_record = create_memory_record(
        title: extracted_memory.corrected_title,
        body: extracted_memory.corrected_body,
        source: "user_corrected",
        confidence: "confirmed"
      )
      extracted_memory.update!(review_attributes(status: "corrected", canonical_memory_record: memory_record))
      record_approval("corrected")
    end

    def create_memory_record(attributes)
      extracted_memory.relationship_profile.memory_records.create!(attributes.merge(status: "active"))
    end

    def review_attributes(attributes)
      attributes.merge(reviewed_by: reviewer, reviewed_at: Time.current)
    end

    def complete_recap_if_reviewed
      recap = extracted_memory.conversation_recap
      recap.lock!
      return if recap.extracted_memories.where(status: "pending").exists?

      recap.update!(extraction_status: "completed", extraction_approved_at: Time.current)
    end

    def record_approval(result)
      metadata = if queue_request
        { request_kind: queue_request.kind, result: result == "corrected" ? "edit" : "approve" }
      else
        { result: }
      end
      AuditEvent.record!(
        user: reviewer,
        actor: reviewer,
        action: "approval.granted",
        target: queue_request || extracted_memory.relationship_profile,
        metadata:
      )
    end

    def finalize_queue_request!
      queue_decision = decision == "correct" ? "edit" : decision
      status = queue_decision.in?(%w[approve edit]) ? "approved" : "rejected"
      occurred_at = Time.current
      queue_request.update!(status:, decided_at: occurred_at, deferred_until: nil)
      queue_request.approval_decisions.create!(user: reviewer, decision: queue_decision, occurred_at:)
      return unless queue_decision == "reject"

      AuditEvent.record!(
        user: reviewer,
        actor: reviewer,
        action: "approval.rejected",
        target: queue_request,
        metadata: { request_kind: queue_request.kind, result: queue_decision },
        occurred_at:
      )
    end
  end
end
