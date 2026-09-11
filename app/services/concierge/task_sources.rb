module Concierge
  class TaskSources
    MAX_DEPTH = 12
    PLAN_FIELDS = %w[title occasion_type tone effort_level starts_on budget_cents guest_list notes].freeze

    def self.capture(plan:, turn:, context:, task_ids:)
      {
        "locale" => turn.locale,
        "plan_version" => plan_version(plan),
        "sources" => context.sources.map { |source| { "id" => source.id, "version" => RecordVersion.digest(source.to_h) } },
        "tasks" => plan.plan_tasks.where(id: task_ids).order(:id).map { |task| { "id" => task.id, "version" => input_version(task) } }
      }
    end

    def self.input_visible?(task, turn:, visited: [], allow_superseded: false, memo: {})
      return false unless task && turn && (allow_superseded || !task.superseded?)
      return false if visited.include?(task.id) || visited.length >= MAX_DEPTH
      return memo[task.id] if memo.key?(task.id)
      profile = task.event_plan.relationship_profile
      return false unless profile.user_id == turn.conversation.user_id && !profile.archived?
      Context.verify!(turn:)
      memo[task.id] = if task.origin == "ai"
        current?(task, turn:, visited: visited + [ task.id ], memo:)
      else
        OccasionSources.sources_authorized?(task.source_context, profile_id: profile.id, turn:, plan: task.event_plan, visited: visited + [ task.id ], memo:)
      end
    rescue Error, ActiveRecord::RecordNotFound
      false
    end

    def self.context(plan:, turn:, locale: turn.locale, visited: [], memo: {})
      profile = plan.relationship_profile
      selected = turn.context["relationship_profile_id"] == profile.id
      ::EventPlans::ContextBuilder.new(event_plan: plan, locale:,
        private_note_ids: selected ? Array(turn.context["private_note_ids"]) : [],
        vault_item_ids: selected ? Array(turn.context["vault_item_ids"]) : [],
        task_filter: ->(task) { input_visible?(task, turn:, visited:, memo:) }).call
    end

    def self.authorization_version(profile:, turn:)
      RecordVersion.digest([ profile.id, Context.profile_snapshot(profile),
        turn.context.slice("relationship_profile_id", "private_note_ids", "vault_item_ids", "selected_versions")
          .merge("private_context_ids" => Context.private_note_provenance(turn.context)) ])
    end

    def self.option_current?(option, turn:, visited: [], memo: {})
      origin_contexts(type: "BackupOption", id: option.id, user: turn.conversation.user, name: "backups.generate").any? do |data|
        context_current?(data, plan: option.backup_plan.event_plan, turn:, visited:, memo:)
      end
    end

    def self.current?(task, turn:, visited:, memo:)
      if task.backup_option
        return option_current?(task.backup_option, turn:, visited:, memo:)
      end
      origin_contexts(type: "PlanTask", id: task.id, user: turn.conversation.user, name: "plan_ideas.generate").any? do |data|
        context_current?(data, plan: task.event_plan, turn:, visited:, memo:) &&
          task.source_context.all? { |source| data["sources"].any? { |input| input["id"] == source["id"] } }
      end
    end
    private_class_method :current?

    def self.origin_contexts(type:, id:, user:, name:)
      key = ConciergeAction.generated_source_key(type:, id:)
      ConciergeAction.joins(turn: :conversation).where(concierge_conversations: { user_id: user.id })
        .where(state: "succeeded", name:).where("source_keys @> ARRAY[?]::text[]", key)
        .map { |action| action.result["task_generation_context"] }
    end
    private_class_method :origin_contexts

    def self.context_current?(data, plan:, turn:, visited:, memo:)
      return false unless data.is_a?(Hash) && data["locale"].in?(%w[en es]) && data["sources"].is_a?(Array) && data["tasks"].is_a?(Array)
      return false unless data["authorization_version"] == authorization_version(profile: plan.relationship_profile, turn:)
      return false unless data["plan_version"] == plan_version(plan)
      current = context(plan:, turn:, locale: data["locale"], visited:, memo:).sources.index_by(&:id)
      return false unless data["sources"].all? { |source| current[source["id"]] && RecordVersion.digest(current[source["id"]].to_h) == source["version"] }
      data["tasks"].all? do |reference|
        input = plan.plan_tasks.find_by(id: reference["id"])
        input && input_version(input) == reference["version"] && input_visible?(input, turn:, visited:, allow_superseded: true, memo:)
      end
    end
    private_class_method :context_current?

    def self.input_version(task)
      RecordVersion.digest(task.attributes.except("updated_at", "completed_at", "superseded_at", "lock_version"))
    end
    private_class_method :input_version

    def self.plan_version(plan)
      RecordVersion.digest(plan.attributes.slice(*PLAN_FIELDS))
    end
    private_class_method :plan_version
  end
end
