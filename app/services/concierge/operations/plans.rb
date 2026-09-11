module Concierge
  module Operations
    class Plans < ProfileRecords
      CLEARABLE_FIELDS = %w[starts_on budget_cents guest_list notes].freeze
      NAMESPACE = "plans"
      ASSOCIATION = :event_plans
      FIELDS = { title: :string, occasion_type: EventPlan::OCCASION_TYPES, tone: EventPlan::TONES,
        effort_level: EventPlan::EFFORT_LEVELS, starts_on: :date, budget_cents: :integer,
        guest_list: :string, notes: :string }.freeze
      REQUIRED = %w[title occasion_type].freeze
      SEARCH = :title_cont
      TITLE = :title
      BODY = :notes

      def self.definitions
        super.reject { |operation| operation.action.in?(%w[create destroy]) } + [
          define("create", description: "Start an event plan with the existing occasion checklist. Use a matching important date as provenance when available. Budget is integer cents, not a payment.",
            fields: SCOPE_FIELDS.merge(FIELDS).merge(important_date_id: :uuid, prior_event_plan_id: :uuid), required: REQUIRED)
        ] + %w[complete reopen archive].map do |event|
          define(event, description: "#{event.capitalize} an identified event plan.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], confirmation: event == "archive")
        end
      end

      def scope
        super.visible
      end

      def create
        authorize!(user.event_plans.new(relationship_profile: profile), :create)
        if arguments["important_date_id"]
          Sources.scope(profile:, association: :important_dates, turn:).find(arguments["important_date_id"])
        end
        Sources.scope(profile:, association: :event_plans, turn:).find(arguments["prior_event_plan_id"]) if arguments["prior_event_plan_id"]
        record = ProfessionalScope.create_and_select!(handler: self, collection: "event_plans") do
          ::EventPlans::Create.call(user:, relationship_profile: profile,
            attributes: attributes.slice(*FIELDS.keys.map(&:to_s)).symbolize_keys,
            important_date_id: arguments["important_date_id"], prior_event_plan_id: arguments["prior_event_plan_id"], locale: turn.locale)
        end
        plan_result(record)
      end

      def update
        authorize!(target, :update)
        ::EventPlans::Update.call(event_plan: target, attributes:, locale: turn.locale)
        plan_result(target)
      end

      %i[complete reopen archive].each do |event|
        define_method(event) do
          authorize!(target, event)
          target.public_send("#{event}!")
          plan_result(target).merge("archived" => event == :archive)
        end
      end

      def record_receipt(record)
        sources = record.source_context.select { |source| OccasionSources.sources_authorized?([ source ], profile_id: record.relationship_profile_id, turn:, plan: record) }
        super.merge("state" => record.status, "source_context" => sources)
      end

      private

      def plan_result(record)
        tasks = record.plan_tasks.current.ordered.limit(LIMIT).select { |task| OccasionSources.task_visible?(task, turn:) }.map { |task| Tasks.receipt_for(task) }
        { "record" => record_receipt(record), "records" => tasks }
      end
    end
  end
end
