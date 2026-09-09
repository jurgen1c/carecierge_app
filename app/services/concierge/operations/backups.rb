module Concierge
  module Operations
    class Backups < Generated
      FIELDS = { event_plan_id: :uuid }.freeze

      def self.namespace = "backups"

      def self.definitions
        [
          define("generate", description: "Prepare three source-backed alternatives for a disruption to an existing occasion. Does not change its active tasks.",
            fields: FIELDS.merge(scenario: BackupPlan::SCENARIOS), required: %w[event_plan_id scenario], provider_work: true),
          define("search", description: "Read available backup options for an occasion with costs, tradeoffs and proposed task changes. Follow next_page to continue.", fields: FIELDS.merge(page: :integer), required: %w[event_plan_id], read_only: true),
          define("read", description: "Read one identified backup option.", fields: FIELDS.merge(id: :uuid), required: %w[event_plan_id id], read_only: true),
          define("promote", description: "Preview applying this backup option. Requires an inline decision before replacing the listed tasks and retiring their reviewed reminders.",
            fields: FIELDS.merge(id: :uuid), required: %w[event_plan_id id], confirmation: true)
        ]
      end

      def plan
        @plan ||= user.event_plans.for_active_relationships.visible.find(arguments.fetch("event_plan_id"))
      end

      def profile
        raise ActiveRecord::RecordNotFound unless OccasionSources.plan_visible?(plan, turn:)
        plan.relationship_profile
      end

      def target
        @target ||= scope.find(arguments["id"]).tap do |option|
          raise ContextUnavailable unless OccasionSources.backup_visible?(option, turn:)
        end if arguments["id"]
      end

      def scope
        BackupOption.where(backup_plan_id: plan.backup_plans.where.not(status: "superseded").select(:id))
      end

      def with_record_locks
        plan.with_mutation_lock do
          target&.backup_plan&.lock!
          super
        end
      end

      def precondition
        super.merge("plan_version" => plan.generation_version, "plan_content_version" => RecordVersion.for(plan))
      end

      def preview
        return super unless target
        tasks = plan.plan_tasks.current.where(id: target.replacement_task_ids).pluck(:title)
        reminders = target.reviewed_reminders.map { |reminder| reminder.fetch("title") }
        [ target.title, target.summary, *target.change_summary,
          I18n.t("concierge.backup_replaces", tasks: tasks.join(", "), reminders: reminders.join(", ")) ].join("\n")
      end

      def generate(on_persist:)
        authorize!(plan, :update)
        options = generation_options.except(:relationship_profile)
        provenance = nil
        ::BackupPlans::Generate.call(**options, event_plan: plan, scenario: arguments.fetch("scenario"),
          task_filter: ->(task) { TaskSources.input_visible?(task, turn:) },
          on_prepare: ->(context:, task_ids:) { provenance = TaskSources.capture(plan:, turn:, context:, task_ids:) },
          on_persist: ->(backup) do
            provenance["authorization_version"] = TaskSources.authorization_version(profile:, turn:)
            # ProviderExecution persists and verifies this origin in the same transaction.
            on_persist.call(backup_result(backup, check_origin: false).merge("task_generation_context" => provenance))
          end)
      end

      def search
        authorize!(plan, :show)
        matches = SearchRecords.call(scope:, page: arguments.fetch("page", 1), order: { created_at: :desc, position: :asc, id: :asc }) do |option|
          OccasionSources.backup_visible?(option, turn:)
        end
        { "records" => matches.records.map { |option| option_receipt(option) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(plan, :show)
        { "record" => option_receipt(target) }
      end

      def promote
        authorize!(plan, :update)
        ::BackupPlans::Promote.call(actor: user, backup_option: target,
          task_filter: ->(task) { TaskSources.input_visible?(task, turn:) },
          vault_lease: PrivacyVault::Lease.from_session(turn.context["vault_lease"]))
        { "record" => option_receipt(target.reload),
          "records" => plan.plan_tasks.current.ordered.limit(LIMIT).select { |task| OccasionSources.task_visible?(task, turn:) }.map { |task| Tasks.receipt_for(task) } +
            [ receipt(plan.reload, title: plan.title, body: plan.notes) ],
          "superseded" => target.replacement_task_ids.map { |id| { "record_type" => "PlanTask", "id" => id } } +
            target.reviewed_reminders.map { |reminder| { "record_type" => "Reminder", "id" => reminder.fetch("id") } } }
      rescue ::BackupPlans::PromotionUnavailableError
        raise RequestConflict
      end

      private

      def backup_result(backup, check_origin: true)
        retired = BackupOption.where(backup_plan_id: plan.backup_plans.where(status: "superseded").select(:id),
          id: History.referenced_ids(turn, record_type: "BackupOption")).pluck(:id)
        { "records" => backup.backup_options.map { |option| option_receipt(option, check_origin:) },
          "superseded" => retired.map { |id| { "record_type" => "BackupOption", "id" => id } } }
      end

      def option_receipt(option, check_origin: true)
        raise ContextUnavailable unless OccasionSources.backup_visible?(option, turn:, check_origin:)
        receipt(option, title: option.title, body: option.summary, relationship_profile_id: profile.id, event_plan_id: plan.id,
          certainty: "inferred", effort: option.effort, timing: option.timing, estimated_cost_cents: option.estimated_cost_cents,
          cost_level: option.cost_level, relationship_fit: option.relationship_fit, change_summary: option.change_summary,
          preserved_constraints: option.preserved_constraints, replacement_task_ids: option.replacement_task_ids,
          reviewed_reminders: option.reviewed_reminders, tasks: option.task_blueprints, sources: option.source_context)
      end
    end
  end
end
