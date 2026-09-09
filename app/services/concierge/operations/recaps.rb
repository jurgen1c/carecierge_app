module Concierge
  module Operations
    class Recaps < ProfileRecords
      CLEARABLE_FIELDS = %w[transcript].freeze
      NAMESPACE = "recaps"
      ASSOCIATION = :conversation_recaps
      FIELDS = { title: :string, body: :string, occurred_at: :datetime,
        capture_source: ConversationRecap::CAPTURE_SOURCES, transcript: :string, request_memory_extraction: :boolean }.freeze
      REQUIRED = %w[title body occurred_at].freeze
      SEARCH = :title_or_body_cont
      TITLE = :title
      BODY = :body

      def self.definitions
        super + [ define("retry_extraction", description: "Retry failed memory extraction from this recap.",
          fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], feature: "ai_memory_extraction") ]
      end

      def precondition
        return super unless target

        super.merge("extraction_version" => RecordVersion.digest([
          target.attributes.slice(*RecordVersion::RECAP_EXTRACTION_FIELDS),
          target.extracted_memories.reorder(:id).pluck(:id)
        ]))
      end

      def retry_extraction
        authorize!(target, :retry_extraction)
        raise RequestConflict unless ConversationRecaps::RetryExtraction.call(target)
        { "record" => record_receipt(target) }
      end

      def record_receipt(record)
        super.merge("extraction_status" => record.extraction_status).except("transcript", "request_memory_extraction")
      end

      private

      def persist!(record)
        enabled = FeatureFlag.enabled?("ai_memory_extraction", user:, environment: Rails.env)
        raise PermissionDenied if arguments["request_memory_extraction"] && !enabled
        raise ContextUnavailable if profile.professional? && arguments["request_memory_extraction"]

        record.assign_attributes(attributes)
        raise ActiveRecord::RecordInvalid, record unless ConversationRecaps::Save.call(record, extraction_enabled: enabled)
      end
    end
  end
end
