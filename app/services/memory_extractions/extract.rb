module MemoryExtractions
  class Extract
    def self.call(conversation_recap:, extractor: OpenAiExtractor.new)
      new(conversation_recap:, extractor:).call
    end

    def initialize(conversation_recap:, extractor:)
      @conversation_recap = conversation_recap
      @extractor = extractor
    end

    def call
      return unless start_processing

      proposals = extractor.extract(conversation_recap)
      persist_proposals(Array(proposals))
    rescue ExtractionError, ActiveRecord::RecordInvalid, JSON::ParserError
      fail_extraction
    end

    private

    attr_reader :conversation_recap, :extractor

    def start_processing
      conversation_recap.with_lock do
        next false unless conversation_recap.extraction_status.in?(%w[requested processing])

        conversation_recap.update!(
          extraction_status: "processing",
          extraction_started_at: Time.current,
          extraction_completed_at: nil,
          extraction_error_code: nil
        )
        true
      end
    end

    def persist_proposals(proposals)
      ApplicationRecord.transaction do
        conversation_recap.lock!
        return unless conversation_recap.extraction_status == "processing"

        proposal_attributes = proposals.map { |attributes| attributes.to_h.symbolize_keys }
        validate_source_excerpts!(proposal_attributes)

        proposal_attributes.each do |attributes|
          conversation_recap.extracted_memories.create!(
            attributes.slice(:category, :title, :body, :source_excerpt, :confidence).merge(
              relationship_profile: conversation_recap.relationship_profile
            )
          )
        end

        completed_at = Time.current
        conversation_recap.update!(
          extraction_status: proposals.empty? ? "completed" : "ready_for_review",
          extraction_completed_at: completed_at,
          extraction_approved_at: proposals.empty? ? completed_at : nil
        )
        create_timeline_entry(proposals.size, completed_at)
        record_audit_event(proposals.size, completed_at)
      end
    end

    def create_timeline_entry(count, occurred_at)
      conversation_recap.relationship_profile.timeline_entries.create!(
        entry_type: "ai_extraction",
        origin: "system",
        title: I18n.t("extracted_memories.timeline.title"),
        body: I18n.t("extracted_memories.timeline.body", count:),
        occurred_at:
      )
    end

    def record_audit_event(count, occurred_at)
      profile = conversation_recap.relationship_profile
      AuditEvent.record!(
        user: profile.user,
        actor: nil,
        actor_kind: "ai",
        source: "ai",
        action: "ai.memory_extracted",
        target: profile,
        metadata: { result: count.zero? ? "no_proposals" : "review_required" },
        occurred_at:
      )
    end

    def fail_extraction
      conversation_recap.with_lock do
        return unless conversation_recap.extraction_status.in?(%w[requested processing])

        conversation_recap.update!(
          extraction_status: "failed",
          extraction_completed_at: Time.current,
          extraction_error_code: "extraction_failed"
        )
      end
    end

    def validate_source_excerpts!(proposals)
      sources = [ conversation_recap.title, conversation_recap.body, conversation_recap.transcript ]
        .compact
        .map(&:squish)

      return if proposals.all? do |attributes|
        excerpt = attributes[:source_excerpt].to_s.squish
        excerpt.present? && sources.any? { |source| source.include?(excerpt) }
      end

      raise ExtractionError, "AI extraction response contained unsupported evidence"
    end
  end
end
