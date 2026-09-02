module EventPlanVendors
  class Detach
    def self.call(event_plan:, assignment:) = new(event_plan:, assignment:).call

    def initialize(event_plan:, assignment:)
      @event_plan = event_plan
      @assignment = assignment
    end

    def call
      event_plan.with_mutation_lock do
        event_plan.reload
        raise ActiveRecord::RecordNotFound unless event_plan.active?

        event_plan.event_plan_vendors.find(assignment.id).destroy!
      end
    end

    private

    attr_reader :event_plan, :assignment
  end
end
