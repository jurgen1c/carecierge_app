module EventPlans
  class Update
    TEMPLATE_ATTRIBUTES = %i[phase kind title details due_on].freeze
    TemplateMatch = Data.define(:task_id, :position, :matching_attributes, :fully_managed)
    TemplateState = Data.define(:matches, :positions)

    def self.call(event_plan:, attributes:, locale: I18n.locale)
      new(event_plan:, attributes:, locale:).call
    end

    def initialize(event_plan:, attributes:, locale:)
      @event_plan = event_plan
      @attributes = attributes
      @locale = locale
    end

    def call
      event_plan.with_mutation_lock do
        previous_starts_on = event_plan.starts_on
        previous_occasion_type = event_plan.occasion_type
        legacy_anniversary = starts_on_change_requested? && legacy_anniversary_templates?(
          occasion_type: previous_occasion_type,
          tasks: event_plan.plan_tasks.current.where(origin: "template").to_a,
          starts_on: previous_starts_on,
          tone: event_plan.tone,
          effort_level: event_plan.effort_level
        )
        template_state = if template_context_change_requested?
          template_state(
            occasion_type: previous_occasion_type,
            starts_on: previous_starts_on,
            tone: event_plan.tone,
            effort_level: event_plan.effort_level
          )
        else
          TemplateState.new(matches: [], positions: [])
        end
        event_plan.update!(attributes)
        if event_plan.saved_change_to_starts_on?
          rebase_template_deadlines(previous_starts_on:, previous_occasion_type:, legacy_anniversary:)
        end
        reconcile_template_copy!(template_state:) if saved_template_context_change?
        event_plan.increment!(:generation_version)
      end
      event_plan
    end

    private

    attr_reader :event_plan, :attributes, :locale

    def template_context_change_requested?
      return true if attribute_change_requested?(:occasion_type)
      return false unless event_plan.occasion_type == "anniversary"

      %i[tone effort_level].any? { |attribute| attribute_change_requested?(attribute) }
    end

    def starts_on_change_requested? = attribute_change_requested?(:starts_on)

    def attribute_change_requested?(attribute)
      key = attributes.key?(attribute) ? attribute : attribute.to_s
      attributes.key?(key) && attributes[key].to_s != event_plan.public_send(attribute).to_s
    end

    def saved_template_context_change?
      event_plan.saved_change_to_occasion_type? ||
        event_plan.occasion_type == "anniversary" &&
          (event_plan.saved_change_to_tone? || event_plan.saved_change_to_effort_level?)
    end

    def template_state(occasion_type:, starts_on:, tone:, effort_level:)
      tasks = template_tasks_for_reconciliation
      current_templates_by_locale = %i[en es].map do |template_locale|
        Template.for(
          occasion_type:,
          starts_on:,
          tone:,
          effort_level:,
          locale: template_locale
        ).index_by { |task| task[:position] }
      end
      templates_by_locale = if legacy_anniversary_templates?(
        occasion_type:,
        tasks:,
        starts_on:,
        tone:,
        effort_level:
      )
        %i[en es].map do |template_locale|
          Template.legacy_anniversary_for(starts_on:, locale: template_locale).index_by { |task| task[:position] }
        end
      else
        current_templates_by_locale
      end

      matches = tasks.map do |task|
        templates = templates_by_locale.filter_map { |by_position| by_position[task.position] }
        matching_attributes = if task.completed?
          []
        else
          TEMPLATE_ATTRIBUTES.select do |attribute|
            templates.any? { |template| task.public_send(attribute) == template[attribute] }
          end
        end
        fully_managed = task.source_context.empty? && task.backup_option_id.nil? &&
          matching_attributes.length == TEMPLATE_ATTRIBUTES.length
        TemplateMatch.new(task_id: task.id, position: task.position, matching_attributes:, fully_managed:)
      end
      TemplateState.new(matches:, positions: templates_by_locale.first.keys)
    end

    def template_tasks_for_reconciliation
      promoted_replacement_task_ids = BackupOption
        .joins(:backup_plan)
        .where(backup_plans: { event_plan_id: event_plan.id })
        .where.not(promoted_at: nil)
        .pluck(:replacement_task_ids)
        .flatten
      templates = event_plan.plan_tasks.where(origin: "template")

      templates.where(superseded_at: nil).or(templates.where(id: promoted_replacement_task_ids)).to_a
    end

    def legacy_anniversary_templates?(occasion_type:, tasks:, starts_on:, tone:, effort_level:)
      return false unless occasion_type.to_s == "anniversary"

      legacy_templates = %i[en es].map do |template_locale|
        Template.legacy_anniversary_for(starts_on:, locale: template_locale).index_by { |task| task[:position] }
      end
      current_templates = %i[en es].map do |template_locale|
        Template.for(
          occasion_type:,
          starts_on:,
          tone:,
          effort_level: "high",
          locale: template_locale
        ).index_by { |task| task[:position] }
      end
      comparable_tasks = tasks.select do |task|
        task.source_context.empty? && task.backup_option_id.nil? &&
          template_at_position?(task.position, legacy_templates) &&
          template_at_position?(task.position, current_templates)
      end
      return false if comparable_tasks.empty?

      comparable_tasks.sum { |task| template_match_score(task, legacy_templates) } >
        comparable_tasks.sum { |task| template_match_score(task, current_templates) }
    end

    def template_at_position?(position, templates_by_locale)
      templates_by_locale.any? { |templates| templates.key?(position) }
    end

    def template_match_score(task, templates_by_locale)
      templates_by_locale.filter_map { |templates| templates[task.position] }.map do |template|
        TEMPLATE_ATTRIBUTES.count { |attribute| task.public_send(attribute) == template[attribute] }
      end.max.to_i
    end

    def reconcile_template_copy!(template_state:)
      templates = Template.for(
        occasion_type: event_plan.occasion_type,
        starts_on: event_plan.starts_on,
        tone: event_plan.tone,
        effort_level: event_plan.effort_level,
        locale:
      ).index_by { |task| task[:position] }

      template_state.matches.each do |match|
        task = event_plan.plan_tasks.find_by(id: match.task_id)
        next unless task

        template = templates[match.position]
        if template
          updates = template.slice(*match.matching_attributes)
          task.update!(updates) if updates.any?
        elsif match.fully_managed
          task.destroy!
        end
      end

      introduced_positions = templates.keys - template_state.positions
      occupied_positions = event_plan.plan_tasks
        .reorder(nil)
        .where(origin: "template", position: introduced_positions)
        .distinct
        .pluck(:position)
      templates.slice(*introduced_positions).except(*occupied_positions).each_value do |template|
        event_plan.plan_tasks.create!(template)
      end
    end

    def rebase_template_deadlines(previous_starts_on:, previous_occasion_type:, legacy_anniversary:)
      previous_templates = templates_by_position(
        starts_on: previous_starts_on,
        occasion_type: previous_occasion_type,
        legacy_anniversary:
      )
      next_templates = templates_by_position(
        starts_on: event_plan.starts_on,
        occasion_type: event_plan.occasion_type,
        legacy_anniversary:
      )
      event_plan.plan_tasks.where(origin: "template").order(:id).each do |task|
        next unless previous_templates.key?(task.position)

        previous_deadline = previous_templates.dig(task.position, :due_on)
        next unless task.due_on == previous_deadline
        next unless next_templates.key?(task.position)

        task.update!(due_on: next_templates.dig(task.position, :due_on))
      end
    end

    def templates_by_position(starts_on:, occasion_type:, legacy_anniversary:)
      templates = if legacy_anniversary
        Template.legacy_anniversary_for(starts_on:, locale: :en)
      else
        Template.for(
          occasion_type:,
          starts_on:,
          effort_level: "high",
          locale: :en
        )
      end
      templates.index_by { |template| template[:position] }
    end
  end
end
