module Concierge
  module Operations
    class Memories < Base
      CLEARABLE_FIELDS = %w[stale_after correction_note].freeze
      SCOPE_FIELDS = { relationship_profile_id: :uuid }.freeze
      WRITE_FIELDS = SCOPE_FIELDS.merge(title: :string, body: :string, stale_after: :date).freeze

      def self.namespace = "memories"

      def self.definitions
        [
          define("search", description: "Recall saved current memories with provenance. Use keywords from the user's question and follow next_page for older matches.", fields: SCOPE_FIELDS.merge(query: :string, page: :integer), read_only: true),
          define("read", description: "Read a specific authorized saved memory.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], read_only: true),
          define("create", description: "Save a memory the user explicitly asks to remember. Never save your own inference as a confirmed fact.", fields: WRITE_FIELDS, required: %w[title body]),
          define("propose", description: "Offer an ordinary non-sensitive interpretation of the user's current words as an inline proposal. Include an exact supporting excerpt from the current user message. Nothing is saved as a memory until the owner accepts the exact wording; it remains labeled inferred. Use create instead for an explicitly requested fact.", fields: WRITE_FIELDS.merge(source_excerpt: :string), required: %w[title body source_excerpt], confirmation: true),
          define("update", description: "Correct a saved memory with a revision and reset previous trust approvals.", fields: WRITE_FIELDS.merge(id: :uuid, correction_note: :string), required: %w[id]),
          define("review", description: "Review a saved memory's accuracy after the user confirms its contents.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], confirmation: true),
          define("destroy", description: "Preview deleting an identified memory. Requires the user's inline confirmation.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], confirmation: true)
        ]
      end

      def target
        @target ||= profile.memory_records.unprotected.find(arguments["id"]) if arguments["id"]
      end

      def precondition
        return super unless arguments.key?("source_excerpt")
        validate_proposal!
        Execute.precondition(profile)
      end

      def preview
        return super unless arguments.key?("source_excerpt")
        I18n.t("concierge.memory_proposal_preview", excerpt: arguments.fetch("source_excerpt"),
          title: arguments.fetch("title"), body: arguments.fetch("body"))
      end

      def search
        return { "records" => [], "reason" => "professional_context_only" } if profile.professional?

        scope = profile.memory_records.unprotected.where(status: %w[active corrected])
          .where("stale_after IS NULL OR stale_after >= ?", Date.current)
        matches = SearchRecords.call(scope:, predicate: :title_or_body_cont, query: arguments["query"], page: arguments.fetch("page", 1))
        { "records" => matches.records.map { |record| memory_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        raise ContextUnavailable if profile.professional?
        authorize!(target, :update)
        { "record" => memory_receipt(target) }
      end

      def create
        record = profile.memory_records.new(attributes.merge(source: "user_confirmed", confidence: "confirmed", status: "active"))
        authorize!(record, :create)
        record.save!
        { "record" => memory_receipt(record) }
      end

      def propose
        validate_proposal!
        record = profile.memory_records.new(attributes.except("source_excerpt").merge(source: "ai_inferred", confidence: "inferred", status: "active"))
        authorize!(record, :create)
        record.save!
        { "record" => memory_receipt(record) }
      end

      def update
        saved = MemoryRecords::Update.call(user:, memory_record: target,
          attributes: attributes.except("correction_note"), correction_note: arguments["correction_note"])
        raise ActiveRecord::RecordInvalid, target unless saved
        { "record" => memory_receipt(target) }
      end

      def review
        authorize!(target, :review)
        raise ActiveRecord::RecordInvalid, target unless target.mark_reviewed!
        { "record" => memory_receipt(target) }
      end

      def destroy
        authorize!(target, :destroy)
        value = memory_receipt(target)
        target.destroy!
        { "record" => value, "deleted" => true }
      end

      private

      def validate_proposal!
        excerpt = arguments.fetch("source_excerpt").strip
        raise InvalidArguments if excerpt.blank? || !turn.content.include?(excerpt)
      end

      def memory_receipt(record)
        receipt(record, title: record.title, body: record.body, source: record.source,
          certainty: record.confidence, review_status: record.status, stale: record.stale?)
      end
    end
  end
end
