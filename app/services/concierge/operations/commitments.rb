module Concierge
  module Operations
    class Commitments < ProfileRecords
      CLEARABLE_FIELDS = %w[due_on notes].freeze
      NAMESPACE = "commitments"
      ASSOCIATION = :commitments
      FIELDS = { title: :string, notes: :string, due_on: :date }.freeze
      REQUIRED = %w[title].freeze
      SEARCH = :title_or_notes_cont
      TITLE = :title
      BODY = :notes

      def self.definitions
        super + %w[complete cancel reopen].map do |event|
          define(event, description: "#{event.capitalize} the identified commitment or promise.",
            fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id])
        end
      end

      %i[complete cancel reopen].each do |event|
        define_method(event) do
          authorize!(target, event)
          raise ActiveRecord::RecordInvalid, target unless ::Commitments::Save.call(target, event:)
          { "record" => record_receipt(target) }
        end
      end

      def record_receipt(record)
        super.merge("state" => record.status)
      end

      private

      def persist!(record)
        raise ActiveRecord::RecordInvalid, record unless ::Commitments::Save.call(record, attributes:)
      end
    end
  end
end
