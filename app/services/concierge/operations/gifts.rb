module Concierge
  module Operations
    class Gifts < ProfileRecords
      CLEARABLE_FIELDS = %w[price_cents occasion vendor notes].freeze
      NAMESPACE = "gifts"
      ASSOCIATION = :gifts
      FIELDS = { name: :string, occasion: :string, price_cents: :integer, vendor: :string,
        notes: :string, status: Gift::EDITABLE_STATUSES }.freeze
      REQUIRED = %w[name].freeze
      SEARCH = :name_or_occasion_or_vendor_cont
      TITLE = :name
      BODY = :notes

      def self.definitions
        super + [ define("mark_given", description: "Record the user's report of giving this gift, the actual date, reaction and outcome. Never buys or sends anything.",
          fields: SCOPE_FIELDS.merge(id: :uuid, given_on: :date, reaction: :string, outcome: Gift::OUTCOMES), required: %w[id given_on]) ]
      end

      def profile
        record = super
        raise PermissionDenied if record.professional? && !record.professional_gifts_allowed?
        record
      end

      def update
        if arguments["status"] && !target.status.in?(Gift::EDITABLE_STATUSES)
          raise InvalidArguments
        end
        super
      end

      def mark_given
        authorize!(target, :mark_given)
        target.mark_given!(given_on: arguments.fetch("given_on"), reaction: arguments["reaction"], outcome: arguments["outcome"])
        { "record" => record_receipt(target) }
      end

      def record_receipt(record)
        self.class.receipt_for(record)
      end

      def self.receipt_for(record)
        { "record_type" => "Gift", "id" => record.id, "relationship_profile_id" => record.relationship_profile_id,
          "version" => RecordVersion.for(record), "title" => record.name, "body" => record.notes,
          "state" => record.status, "price_cents" => record.price_cents, "vendor" => record.vendor,
          "occasion" => record.occasion, "given_on" => record.given_on&.iso8601, "reaction" => record.reaction,
          "outcome" => record.outcome, "manual_record" => true }
      end
    end
  end
end
