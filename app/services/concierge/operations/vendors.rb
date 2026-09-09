module Concierge
  module Operations
    class Vendors < Base
      CLEARABLE_FIELDS = %w[minimum_price_cents maximum_price_cents location availability fit_notes source_name source_url].freeze
      FIELDS = { name: :string, category: Vendor::CATEGORIES, location: :string, availability: :string,
        minimum_price_cents: :integer, maximum_price_cents: :integer, fit_notes: :string,
        source_kind: Vendor::SOURCE_KINDS, source_name: :string, source_url: :string,
        occasion_types_text: :string, preference_tags_text: :string }.freeze

      def self.namespace = "vendors"

      def self.definitions
        [
          define("search", description: "Find the owner's saved manual vendor records. Availability and prices are recorded observations, not live verification.",
            fields: { query: :string, category: Vendor::CATEGORIES, location: :string, page: :integer }, read_only: true),
          define("read", description: "Read a saved vendor record.", fields: { id: :uuid }, required: %w[id], read_only: true),
          define("create", description: "Save user-provided vendor details. Price fields are integer cents. Does not contact the vendor.", fields: FIELDS, required: %w[name category]),
          define("update", description: "Correct a saved manual vendor record.", fields: FIELDS.merge(id: :uuid), required: %w[id]),
          define("destroy", description: "Preview deleting an unused vendor record. Referenced vendors must be retained.", fields: { id: :uuid }, required: %w[id], confirmation: true)
        ] + %w[attach detach].map do |event|
          define(event, description: "#{event.capitalize} this saved vendor to or from an event plan, without contacting anyone.", fields: { id: :uuid, event_plan_id: :uuid }, required: %w[id event_plan_id])
        end
      end

      def plan
        @plan ||= user.event_plans.for_active_relationships.visible.find(arguments["event_plan_id"]) if arguments["event_plan_id"]
      end

      def profile
        record = plan&.relationship_profile
        record ||= super if turn.context["relationship_mode"] == "professional"
        raise ActiveRecord::RecordNotFound if plan && !OccasionSources.plan_visible?(plan, turn:)
        record
      end

      def scope
        VendorSources.vendor_scope(profile:, user:)
      end

      def target
        @target ||= scope.find(arguments["id"]) if arguments["id"]
      end

      def with_record_locks(&block)
        plan ? plan.with_mutation_lock { super(&block) } : super(&block)
      end

      def search
        authorize!(Vendor, :index)
        query = ::Vendors::SearchQuery.new(scope, params: arguments)
        matches = SearchRecords.call(scope: query.resolve, page: arguments.fetch("page", 1))
        { "records" => matches.records.map { |vendor| vendor_receipt(vendor) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(target, :show)
        { "record" => vendor_receipt(target) }
      end

      def create
        vendor = user.vendors.new(attributes)
        authorize!(vendor, :create)
        if profile&.professional?
          ProfessionalScope.create_and_select!(handler: self, collection: "vendors") do
            vendor.save!
            vendor
          end
        else
          vendor.save!
        end
        { "record" => vendor_receipt(vendor) }
      end

      def update
        authorize!(target, :update)
        target.update!(attributes)
        { "record" => vendor_receipt(target) }
      end

      def destroy
        authorize!(target, :destroy)
        value = vendor_receipt(target)
        ::Vendors::Destroy.call(vendor: target)
        { "record" => value, "deleted" => true }
      end

      def attach
        authorize!(plan, :update)
        ::EventPlanVendors::Attach.call(event_plan: plan, vendor: target)
        { "record" => vendor_receipt(target).merge("event_plan_id" => plan.id, "attached" => true) }
      end

      def detach
        authorize!(plan, :update)
        assignment = plan.event_plan_vendors.find_by!(vendor_id: target.id)
        ::EventPlanVendors::Detach.call(event_plan: plan, assignment:)
        { "record" => vendor_receipt(target).merge("event_plan_id" => plan.id, "attached" => false) }
      end

      private

      def vendor_receipt(vendor)
        receipt(vendor, title: vendor.name, body: vendor.fit_notes, category: vendor.category, location: vendor.location,
          relationship_profile_id: profile&.id,
          availability: vendor.availability, minimum_price_cents: vendor.minimum_price_cents, maximum_price_cents: vendor.maximum_price_cents,
          source: vendor.source_label, source_url: vendor.source_url, manual_record: true)
      end
    end
  end
end
