module EventPlans
  class Update
    def self.call(event_plan:, attributes:)
      new(event_plan:, attributes:).call
    end

    def initialize(event_plan:, attributes:)
      @event_plan = event_plan
      @attributes = attributes
    end

    def call
      event_plan.with_mutation_lock do
        previous_starts_on = event_plan.starts_on
        event_plan.update!(attributes)
        rebase_template_deadlines(previous_starts_on:) if event_plan.saved_change_to_starts_on?
        event_plan.increment!(:generation_version)
      end
      event_plan
    end

    private

    attr_reader :event_plan, :attributes

    def rebase_template_deadlines(previous_starts_on:)
      event_plan.plan_tasks.where(origin: "template").order(:id).each do |task|
        previous_deadline = Template.deadline_for(position: task.position, starts_on: previous_starts_on)
        next unless task.due_on == previous_deadline

        task.update!(due_on: Template.deadline_for(position: task.position, starts_on: event_plan.starts_on))
      end
    end
  end
end
