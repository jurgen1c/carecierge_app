module Concierge
  module Operations
    class Desires < ProfileRecords
      CLEARABLE_FIELDS = %w[notes].freeze
      NAMESPACE = "desires"
      ASSOCIATION = :desires
      FIELDS = { title: :string, category: Desire::CATEGORIES, status: Desire::EDITABLE_STATUSES, captured_on: :date, notes: :string }.freeze
      REQUIRED = %w[title category].freeze
      SEARCH = :title_or_notes_cont
      TITLE = :title
      BODY = :notes

      def self.definitions
        super + [ define("fulfill", description: "Record that the user fulfilled this wish, desire, or goal.",
          fields: SCOPE_FIELDS.merge(id: :uuid, fulfilled_on: :date, notes: :string), required: %w[id]) ]
      end

      def fulfill
        authorize!(target, :fulfill)
        raise RequestConflict if target.fulfilled?
        target.fulfill!(fulfilled_on: arguments["fulfilled_on"] || Date.current, notes: arguments["notes"])
        { "record" => record_receipt(target) }
      end

      private

      def persist!(record)
        if record.persisted? && arguments.key?("status") && !record.status.in?(Desire::EDITABLE_STATUSES)
          raise RequestConflict
        end
        super
      end
    end
  end
end
