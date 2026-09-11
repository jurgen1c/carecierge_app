module Concierge
  module Operations
    class Shortlists < Base
      def self.namespace = "shortlists"

      def self.definitions
        [
          define("search", description: "Find vendor comparisons for this relationship. Follow next_page to continue, even when an encrypted-search page has no matches.", fields: { relationship_profile_id: :uuid, query: :string, page: :integer }, read_only: true),
          define("read", description: "Read a vendor comparison and its current choices.", fields: { id: :uuid }, required: %w[id], read_only: true),
          define("create", description: "Start a vendor comparison with up to five saved vendors. This records choices without contacting or booking anyone.",
            fields: { relationship_profile_id: :uuid, event_plan_id: :uuid, title: :string, vendor_ids: :uuid_list }, required: %w[title vendor_ids])
        ]
      end

      def target
        @target ||= user.vendor_shortlists.find(arguments["id"]) if arguments["id"]
      end

      def plan
        return target.event_plan if target
        @plan ||= user.event_plans.for_active_relationships.visible.find(arguments["event_plan_id"]) if arguments["event_plan_id"]
      end

      def profile
        record = target&.relationship_profile || plan&.relationship_profile || super
        raise ContextUnavailable if record.archived?
        if target && !VendorSources.shortlist_visible?(target, user:, turn:)
          raise ActiveRecord::RecordNotFound
        end
        raise ActiveRecord::RecordNotFound if plan && !OccasionSources.plan_visible?(plan, turn:)
        raise ActiveRecord::RecordNotFound if arguments["relationship_profile_id"] && record.id != arguments["relationship_profile_id"]
        record
      end

      def with_record_locks(&block)
        plan ? plan.with_mutation_lock { super(&block) } : super(&block)
      end

      def create
        vendor_ids = arguments.fetch("vendor_ids").uniq
        vendors = VendorSources.vendor_scope(profile:, user:).where(id: vendor_ids).to_a
        raise ActiveRecord::RecordNotFound unless vendors.length == vendor_ids.length
        candidate = user.vendor_shortlists.new(relationship_profile: profile, event_plan: plan)
        authorize!(candidate, :create)
        record = ProfessionalScope.create_and_select!(handler: self, collection: "vendor_shortlists") do
          ::VendorShortlists::Create.call(user:, attributes: { title: arguments.fetch("title"), relationship_profile: profile, event_plan: plan }, vendors:)
        end
        shortlist_result(record)
      end

      def read
        authorize!(target, :show)
        shortlist_result(target)
      end

      def search
        authorize!(profile, :show)
        scope = profile.professional? ? profile.work_context.selected("vendor_shortlists") : user.vendor_shortlists.where(relationship_profile: profile)
        matches = SearchRecords.call(scope:, predicate: :title_cont,
          query: arguments["query"], page: arguments.fetch("page", 1)) do |record|
          !record.event_plan || OccasionSources.plan_visible?(record.event_plan, turn:)
        end
        { "records" => matches.records.map { |record| receipt(record, title: record.title, event_plan_id: record.event_plan_id, manual_record: true) }, "next_page" => matches.next_page }
      end

      def shortlist_result(record)
        { "record" => receipt(record, title: record.title, event_plan_id: record.event_plan_id, manual_record: true),
          "records" => record.vendor_options.includes(:vendor).ordered.select { |option| VendorSources.option_visible?(option, user:, turn:) }.map { |option| VendorOptions.receipt_for(option) } }
      end
    end
  end
end
