module Concierge
  module Operations
    class PlanIdeas < Generated
      def self.namespace = "plan_ideas"

      def self.definitions
        [ define("generate", description: "Add up to six source-backed suggestions to an existing plan while preserving current tasks. Suggestions remain editable and never book, buy or contact anyone. Uses only selected sensitive context.",
            fields: { event_plan_id: :uuid }, required: %w[event_plan_id], provider_work: true) ]
      end

      def plan
        @plan ||= user.event_plans.for_active_relationships.visible.find(arguments.fetch("event_plan_id"))
      end

      def profile
        raise ActiveRecord::RecordNotFound unless OccasionSources.plan_visible?(plan, turn:)
        plan.relationship_profile
      end

      def with_record_locks
        plan.with_mutation_lock { yield }
      end

      def generate(on_persist:)
        authorize!(plan, :update)
        provenance = nil
        ::EventPlans::Suggest.call(**generation_options.except(:relationship_profile), event_plan: plan,
          task_filter: ->(task) { TaskSources.input_visible?(task, turn:) },
          on_prepare: ->(context:, task_ids:) { provenance = TaskSources.capture(plan:, turn:, context:, task_ids:) },
          on_persist: ->(tasks) do
            provenance["authorization_version"] = TaskSources.authorization_version(profile:, turn:)
            on_persist.call("record" => Plans.new(turn:, arguments: {}).record_receipt(plan.reload),
              "records" => tasks.map { |task| Tasks.receipt_for(task) }, "task_generation_context" => provenance)
          end)
      end
    end
  end
end
