module BackupPlans
  class Generate
    MAX_RESULTS = 3
    TaskSnapshot = Data.define(:id, :phase, :kind, :title, :details, :due_on, :completed)
    PlanSnapshot = Data.define(
      :title,
      :occasion_type,
      :starts_on,
      :budget_cents,
      :guest_list,
      :notes,
      :existing_tasks
    )

    def self.call(
      actor:,
      event_plan:,
      scenario:,
      private_note_ids: [],
      vault_item_ids: [],
      vault_lease: nil,
      locale: I18n.locale,
      generator: LlmGenerator.new
    )
      new(
        actor:,
        event_plan:,
        scenario:,
        private_note_ids:,
        vault_item_ids:,
        vault_lease:,
        locale:,
        generator:
      ).call
    end

    def initialize(**attributes)
      attributes.each { |key, value| instance_variable_set("@#{key}", value) }
      @scenario = attributes[:scenario].to_s
      @private_note_ids = normalize_ids(attributes[:private_note_ids])
      @vault_item_ids = normalize_ids(attributes[:vault_item_ids])
      @locale = attributes[:locale].to_sym
    end

    def call
      generation_version, initial_context, plan_snapshot = prepare_generation!
      raw_options = generator.generate(
        plan_snapshot:,
        scenario:,
        sources: initial_context.sources,
        locale:,
        count: MAX_RESULTS
      )

      actor.with_lock do
        relationship_profile.with_lock do
          event_plan.with_lock do
            validate_request!
            validate_vault_access!
            current_context = build_context
            reject_stale_generation!(generation_version:, initial_context:, current_context:)
            options = enrich_options(raw_options, sources: current_context.sources, plan_snapshot:)
            raise EventPlans::GenerationError, "Backup plan response had no usable options" if options.empty?
            options = attach_reviewed_reminders(options)

            persist_backup_plan!(
              options:,
              sources: current_context.sources,
              generation_version:,
              context_fingerprint: current_context.fingerprint
            )
          end
        end
      end
    end

    private

    attr_reader :actor, :event_plan, :scenario, :private_note_ids, :vault_item_ids, :vault_lease, :locale, :generator

    def relationship_profile = event_plan.relationship_profile

    def prepare_generation!
      actor.with_lock do
        relationship_profile.with_lock do
          event_plan.with_lock do
            validate_request!
            validate_vault_access!
            context = build_context
            validate_selected_sources!(context)
            record_sensitive_access(context.categories)
            plan_snapshot = build_plan_snapshot(sources: context.sources)
            event_plan.increment!(:generation_version)
            [ event_plan.generation_version, context, plan_snapshot ]
          end
        end
      end
    end

    def validate_request!
      raise ActiveRecord::RecordNotFound unless event_plan.user_id == actor.id
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
      raise ActiveRecord::RecordNotFound unless event_plan.active?
      raise EventPlans::GenerationError, "Backup plan scenario was invalid" unless scenario.in?(BackupPlan::SCENARIOS)
      raise EventPlans::GenerationError, "Backup plan locale was invalid" unless locale.to_s.in?(BackupPlan::LOCALES)
    end

    def validate_vault_access!
      return if vault_item_ids.empty?
      return if vault_lease&.active_for?(actor)

      raise EventPlans::VaultAccessError, "Privacy vault access is required"
    end

    def build_context
      EventPlans::ContextBuilder.new(
        event_plan:,
        private_note_ids:,
        vault_item_ids:,
        locale:
      ).call
    end

    def validate_selected_sources!(context)
      found_ids = context.sources.map(&:id)
      expected_ids = private_note_ids.map { |id| "private_note:#{id}" } + vault_item_ids.map { |id| "vault:#{id}" }
      raise ActiveRecord::RecordNotFound unless (expected_ids - found_ids).empty?
    end

    def build_plan_snapshot(sources:)
      authorized_source_ids = sources.map(&:id)
      tasks = event_plan.plan_tasks.current.ordered.limit(50).filter_map do |task|
        persisted_source_ids = task.source_context.filter_map { |source| source["id"] }
        next unless persisted_source_ids.empty? || (persisted_source_ids - authorized_source_ids).empty?

        TaskSnapshot.new(
          id: task.id,
          phase: task.phase,
          kind: task.kind,
          title: task.title,
          details: task.details,
          due_on: task.due_on,
          completed: task.completed?
        )
      end.freeze
      PlanSnapshot.new(
        title: event_plan.title,
        occasion_type: event_plan.occasion_type,
        starts_on: event_plan.starts_on,
        budget_cents: event_plan.budget_cents,
        guest_list: event_plan.guest_list,
        notes: event_plan.notes,
        existing_tasks: tasks
      )
    end

    def reject_stale_generation!(generation_version:, initial_context:, current_context:)
      return if event_plan.generation_version == generation_version && initial_context.fingerprint == current_context.fingerprint

      raise EventPlans::GenerationSupersededError, "A newer request or plan change superseded these backup options"
    end

    def enrich_options(raw_options, sources:, plan_snapshot:)
      raise EventPlans::GenerationError, "Backup plan response was invalid" unless raw_options.is_a?(Array)

      source_by_id = sources.index_by(&:id)
      replaceable_task_ids = plan_snapshot.existing_tasks.reject(&:completed).map(&:id).to_set
      titles = Set.new
      raw_options.first(MAX_RESULTS).map.with_index do |raw_option, position|
        option = raw_option.to_h.deep_stringify_keys
        title = bounded_text(option.fetch("title"), BackupOption::MAX_TITLE_LENGTH)
        raise EventPlans::GenerationError, "Backup plan response repeated an option" unless titles.add?(title.downcase)

        source_context = cited_sources(option.fetch("source_ids"), source_by_id:)
        replacement_task_ids = normalized_replacement_ids(option.fetch("replacement_task_ids"), replaceable_task_ids:)
        {
          title:,
          summary: bounded_text(option.fetch("summary"), BackupOption::MAX_SUMMARY_LENGTH),
          effort: supported_value(option.fetch("effort"), BackupOption::EFFORTS),
          timing: supported_value(option.fetch("timing"), BackupOption::TIMINGS),
          estimated_cost_cents: estimated_cost(option["estimated_cost_cents"]),
          cost_level: supported_value(option.fetch("cost_level"), BackupOption::COST_LEVELS),
          relationship_fit: supported_value(option.fetch("relationship_fit"), BackupOption::RELATIONSHIP_FITS),
          preserved_constraints: bounded_text_list(option.fetch("preserved_constraints")),
          change_summary: bounded_text_list(option.fetch("change_summary")),
          replacement_task_ids:,
          source_context:,
          task_blueprints: enrich_tasks(option.fetch("tasks"), source_by_id:),
          position:
        }
      end
    rescue KeyError, NoMethodError, TypeError
      raise EventPlans::GenerationError, "Backup plan response was invalid"
    end

    def supported_value(value, supported)
      normalized = value.to_s
      raise EventPlans::GenerationError, "Backup plan response was invalid" unless normalized.in?(supported)

      normalized
    end

    def bounded_text(value, maximum)
      text = value.to_s.squish
      raise EventPlans::GenerationError, "Backup plan response was invalid" if text.blank? || text.length > maximum

      text
    end

    def bounded_text_list(value)
      raise EventPlans::GenerationError, "Backup plan response was invalid" unless value.is_a?(Array)

      items = value.first(BackupOption::MAX_LIST_ITEMS).map do |item|
        bounded_text(item, BackupOption::MAX_LIST_ITEM_LENGTH)
      end
      raise EventPlans::GenerationError, "Backup plan response was invalid" if items.empty?

      items
    end

    def estimated_cost(value)
      return if value.nil?
      return value if value.is_a?(Integer) && value.between?(0, EventPlan::MAX_BUDGET_CENTS)

      raise EventPlans::GenerationError, "Backup plan response was invalid"
    end

    def normalized_replacement_ids(value, replaceable_task_ids:)
      raise EventPlans::GenerationError, "Backup plan response was invalid" unless value.is_a?(Array)

      ids = value.map(&:to_s).uniq
      if ids.length > BackupOption::MAX_TASKS || (ids - replaceable_task_ids.to_a).any?
        raise EventPlans::GenerationError, "Backup plan response tried to replace an unavailable task"
      end
      ids
    end

    def enrich_tasks(raw_tasks, source_by_id:)
      unless raw_tasks.is_a?(Array) && raw_tasks.present? && raw_tasks.length <= BackupOption::MAX_TASKS
        raise EventPlans::GenerationError, "Backup plan response was invalid"
      end

      raw_tasks.map do |raw_task|
        task = raw_task.to_h.deep_stringify_keys
        {
          "phase" => supported_value(task.fetch("phase"), PlanTask::PHASES),
          "kind" => supported_value(task.fetch("kind"), PlanTask::KINDS),
          "title" => bounded_text(task.fetch("title"), PlanTask::MAX_TITLE_LENGTH),
          "details" => optional_bounded_text(task["details"], PlanTask::MAX_DETAILS_LENGTH),
          "due_on" => parse_date(task["due_on"])&.iso8601,
          "source_context" => cited_sources(task.fetch("source_ids"), source_by_id:)
        }
      end
    end

    def optional_bounded_text(value, maximum)
      return if value.blank?

      bounded_text(value, maximum)
    end

    def cited_sources(source_ids, source_by_id:)
      unless source_ids.is_a?(Array) && source_ids.present? && source_ids.length <= BackupOption::MAX_SOURCES
        raise EventPlans::GenerationError, "Backup plan response was invalid"
      end

      source_ids.uniq.map do |source_id|
        source = source_by_id[source_id] || raise(EventPlans::GenerationError, "Backup plan cited an unknown source")
        {
          "id" => source.id,
          "label" => source.label,
          "certainty" => source.certainty,
          "sensitive" => source.sensitive
        }
      end
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      raise EventPlans::GenerationError, "Backup plan response was invalid"
    end

    def attach_reviewed_reminders(options)
      replacement_ids = options.flat_map { |option| option.fetch(:replacement_task_ids) }.uniq
      reminders_by_task_id = event_plan.reminders.active
        .where(plan_task_id: replacement_ids)
        .reorder(:id)
        .map { |reminder| BackupOption.reminder_snapshot(reminder) }
        .group_by { |reminder| reminder.fetch("plan_task_id") }

      options.map do |option|
        reminders = option.fetch(:replacement_task_ids).flat_map do |task_id|
          reminders_by_task_id.fetch(task_id, [])
        end
        if reminders.length > BackupOption::MAX_REVIEWED_REMINDERS
          raise EventPlans::GenerationError, "Backup plan option had too many active reminders"
        end

        option.merge(reviewed_reminders: reminders)
      end
    end

    def persist_backup_plan!(options:, sources:, generation_version:, context_fingerprint:)
      event_plan.backup_plans.where(status: "generated").update_all(status: "superseded", updated_at: Time.current)
      backup_plan = event_plan.backup_plans.create!(
        user: actor,
        scenario:,
        source_context: sources.map { |source| source.to_h.stringify_keys },
        locale: locale.to_s,
        include_private_notes: private_note_ids.any?,
        include_vault_context: vault_item_ids.any?,
        event_plan_generation_version: generation_version,
        context_fingerprint:,
        generated_at: Time.current
      )
      options.each { |attributes| backup_plan.backup_options.create!(attributes) }
      AuditEvent.record!(
        user: actor,
        actor:,
        action: "event_plan.backup_options_generated",
        target: event_plan,
        metadata: { result: "generated", scenario:, count: options.length }
      )
      backup_plan
    end

    def record_sensitive_access(categories)
      return if (categories & %w[private_notes vault]).empty?

      AuditEvent.record!(
        user: actor,
        actor:,
        action: "sensitive_record.accessed",
        target: relationship_profile,
        metadata: { result: "event_plan_backup" }
      )
      return unless categories.include?("vault")

      VaultAccessEvent.record_safely(event_type: "viewed", user: actor, relationship_profile:)
    end

    def normalize_ids(values)
      Array(values).compact_blank.map(&:to_s).uniq.first(EventPlans::ContextBuilder::MAX_PER_KIND)
    end
  end
end
