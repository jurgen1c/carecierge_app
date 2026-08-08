module MemoryExtractions
  class Review
    DECISIONS = %w[approve reject correct].freeze

    def self.call(extracted_memory:, reviewer:, decision:, corrected_title: nil, corrected_body: nil)
      new(
        extracted_memory:,
        reviewer:,
        decision: decision.to_s,
        corrected_title:,
        corrected_body:
      ).call
    end

    def initialize(extracted_memory:, reviewer:, decision:, corrected_title:, corrected_body:)
      @extracted_memory = extracted_memory
      @reviewer = reviewer
      @decision = decision
      @corrected_title = corrected_title
      @corrected_body = corrected_body
    end

    def call
      authorize!
      raise ArgumentError, "Unsupported review decision" unless decision.in?(DECISIONS)

      ApplicationRecord.transaction do
        extracted_memory.lock!
        return extracted_memory unless extracted_memory.pending?

        apply_decision
        complete_recap_if_reviewed
        extracted_memory
      end
    end

    private

    attr_reader :extracted_memory, :reviewer, :decision, :corrected_title, :corrected_body

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
      AuditEvent.record!(
        user: reviewer,
        actor: reviewer,
        action: "approval.granted",
        target: extracted_memory.relationship_profile,
        metadata: { result: }
      )
    end
  end
end
