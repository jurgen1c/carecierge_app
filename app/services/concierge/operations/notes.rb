module Concierge
  module Operations
    class Notes < ProfileRecords
      NAMESPACE = "notes"
      ASSOCIATION = :relationship_notes
      FIELDS = { category: :string, body: :string, private: :boolean }.freeze
      REQUIRED = %w[body].freeze
      SEARCH = :category_or_body_cont
      TITLE = :category
      BODY = :body

      def record_receipt(record)
        receipt(record, title: record.category.presence || I18n.t("concierge.note"),
          body: record.body.to_plain_text, private: record.private?)
      end

      def destroy
        record = target
        super.tap { Context.record_note_change!(turn:, note: record) }
      end

      private

      def authorize_record!(_record, _action)
        authorize!(profile, :update)
      end

      def persist!(record)
        raise ContextUnavailable if profile.professional? && arguments["private"]
        record.assign_attributes(attributes.except("body"))
        record.body = ERB::Util.html_escape(arguments["body"]) if arguments.key?("body")
        record.save!
        Context.record_note_change!(turn:, note: record)
      end
    end
  end
end
