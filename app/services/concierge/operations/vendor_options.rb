module Concierge
  module Operations
    class VendorOptions < Base
      CLEARABLE_FIELDS = %w[notes constraints next_action].freeze
      FIELDS = { shortlist_id: :uuid, id: :uuid }.freeze

      def self.namespace = "vendor_options"

      def self.definitions
        [
          define("create", description: "Add one saved vendor to a comparison of at most five options.", fields: { shortlist_id: :uuid, vendor_id: :uuid }, required: %w[shortlist_id vendor_id]),
          define("update", description: "Update a vendor option's private notes using its last read lock version.", fields: FIELDS.merge(lock_version: :integer, notes: :string, constraints: :string, next_action: :string), required: %w[shortlist_id id lock_version]),
          define("favorite", description: "Set whether this option is a favorite; this is only a manual comparison.", fields: FIELDS.merge(favorite: :boolean), required: %w[shortlist_id id favorite]),
          define("destroy", description: "Preview removing a vendor option from its comparison.", fields: FIELDS, required: %w[shortlist_id id], confirmation: true)
        ] + %w[select reject restore].map do |event|
          define(event, description: "#{event.capitalize} an option in the manual comparison. Does not book or contact a vendor.", fields: FIELDS, required: %w[shortlist_id id])
        end
      end

      def shortlist
        @shortlist ||= user.vendor_shortlists.find(arguments.fetch("shortlist_id"))
      end

      def profile
        record = shortlist.relationship_profile
        raise ActiveRecord::RecordNotFound unless VendorSources.shortlist_visible?(shortlist, user:, turn:)
        record
      end

      def target
        @target ||= shortlist.vendor_options.find(arguments["id"]).tap do |option|
          raise ActiveRecord::RecordNotFound unless VendorSources.option_visible?(option, user:, turn:)
        end if arguments["id"]
      end

      def with_record_locks
        shortlist.with_option_removal_lock { super }
      end

      def create
        vendor = VendorSources.vendor_scope(profile:, user:).find(arguments.fetch("vendor_id"))
        authorize!(shortlist.vendor_options.new(vendor:), :create)
        shortlist.add_vendor!(vendor)
        options_result
      end

      def update
        authorize!(target, :update)
        target.update_details!(attributes.symbolize_keys.slice(:notes, :constraints, :next_action), expected_lock_version: arguments.fetch("lock_version"))
        options_result
      rescue ActiveRecord::StaleObjectError
        raise RequestConflict
      end

      def favorite
        authorize!(target, :update)
        target.toggle_favorite! unless target.favorite? == arguments.fetch("favorite")
        options_result
      end

      %w[select reject restore].each do |event|
        define_method(event) do
          authorize!(target, :update)
          target.public_send("#{event}!")
          options_result
        end
      end

      def destroy
        authorize!(target, :destroy)
        value = self.class.receipt_for(target)
        target.remove!
        { "record" => value, "deleted" => true }
      end

      def self.receipt_for(record)
        { "record_type" => "VendorOption", "id" => record.id, "version" => RecordVersion.for(record),
          "relationship_profile_id" => record.vendor_shortlist.relationship_profile_id, "shortlist_id" => record.vendor_shortlist_id,
          "title" => record.vendor.name, "body" => record.notes, "constraints" => record.constraints, "next_action" => record.next_action,
          "decision" => record.decision, "favorite" => record.favorite?, "lock_version" => record.lock_version, "manual_record" => true }
      end

      private

      def options_result
        { "records" => shortlist.vendor_options.reload.includes(:vendor).select { |record| VendorSources.option_visible?(record, user:, turn:) }.map { |record| self.class.receipt_for(record) } }
      end
    end
  end
end
