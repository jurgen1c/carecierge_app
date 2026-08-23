module EventPlans
  class Update
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
        unchanged_template_positions = if occasion_change_requested?
          unchanged_template_positions(occasion_type: previous_occasion_type)
        else
          []
        end
        event_plan.update!(attributes)
        retemplate_unchanged_copy!(positions: unchanged_template_positions) if event_plan.saved_change_to_occasion_type?
        rebase_template_deadlines(previous_starts_on:) if event_plan.saved_change_to_starts_on?
        event_plan.increment!(:generation_version)
      end
      event_plan
    end

    private

    attr_reader :event_plan, :attributes, :locale

    def occasion_change_requested?
      key = attributes.key?(:occasion_type) ? :occasion_type : "occasion_type"
      attributes.key?(key) && attributes[key].to_s != event_plan.occasion_type
    end

    def unchanged_template_positions(occasion_type:)
      templates_by_locale = %i[en es].map do |template_locale|
        Template.for(occasion_type:, starts_on: event_plan.starts_on, locale: template_locale).index_by { |task| task[:position] }
      end

      event_plan.plan_tasks.where(origin: "template").filter_map do |task|
        task.position if templates_by_locale.any? do |templates|
          template = templates[task.position]
          template && task.title == template[:title] && task.details == template[:details]
        end
      end
    end

    def retemplate_unchanged_copy!(positions:)
      return if positions.empty?

      templates = Template.for(
        occasion_type: event_plan.occasion_type,
        starts_on: event_plan.starts_on,
        locale:
      ).index_by { |task| task[:position] }
      event_plan.plan_tasks.where(origin: "template", position: positions).find_each do |task|
        template = templates.fetch(task.position)
        task.update!(title: template[:title], details: template[:details])
      end
    end

    def rebase_template_deadlines(previous_starts_on:)
      event_plan.plan_tasks.where(origin: "template").order(:id).each do |task|
        previous_deadline = Template.deadline_for(position: task.position, starts_on: previous_starts_on)
        next unless task.due_on == previous_deadline

        task.update!(due_on: Template.deadline_for(position: task.position, starts_on: event_plan.starts_on))
      end
    end
  end
end
