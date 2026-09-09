module Concierge
  module Operations
    class ManualPlanRecords < Base
      def self.namespace = self::NAMESPACE

      def self.definitions
        scope = { event_plan_id: :uuid }
        [
          define("search", description: "Read saved manual #{namespace} for this event plan; these are owner records, not externally verified transactions. Follow next_page to continue.", fields: scope.merge(query: :string, page: :integer), required: %w[event_plan_id], read_only: true),
          define("read", description: "Read one identified manual #{namespace} record and its lock version.", fields: scope.merge(id: :uuid), required: %w[event_plan_id id], read_only: true),
          define("create", description: "Save user-provided manual #{namespace} details. Does not contact, reserve, accept externally, pay, or purchase. Amounts are integer cents with an explicit currency.", fields: scope.merge(self::FIELDS), required: [ "event_plan_id", *self::REQUIRED ]),
          define("update", description: "Correct a manual #{namespace} record with its last read lock version. Status changes record the user's own reported activity; no external action occurs.", fields: scope.merge(self::FIELDS.except(:vendor_id)).merge(id: :uuid, lock_version: :integer), required: %w[event_plan_id id lock_version]),
          define("destroy", description: "Preview deleting this manual #{namespace} record and its associated local records.", fields: scope.merge(id: :uuid), required: %w[event_plan_id id], confirmation: true)
        ]
      end

      def plan
        @plan ||= user.event_plans.for_active_relationships.visible.find(arguments.fetch("event_plan_id"))
      end

      def profile
        raise ActiveRecord::RecordNotFound unless OccasionSources.plan_visible?(plan, turn:)
        plan.relationship_profile
      end

      def scope
        user.public_send(self.class::ASSOCIATION).where(event_plan: plan)
      end

      def target
        @target ||= scope.find(arguments["id"]) if arguments["id"]
      end

      def with_record_locks
        plan.with_lock { super }
      end

      def search
        authorize!(plan, :show)
        matches = SearchRecords.call(scope:, predicate: self.class::SEARCH, query: arguments["query"], page: arguments.fetch("page", 1), order: scope.ordered.order_values)
        { "records" => matches.records.map { |record| record_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(target, :index)
        { "record" => record_receipt(target) }
      end

      def record_attributes
        attributes.slice(*self.class::FIELDS.keys.map(&:to_s)).symbolize_keys
      end
    end
  end
end
