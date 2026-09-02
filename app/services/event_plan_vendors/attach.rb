module EventPlanVendors
  class Attach
    def self.call(event_plan:, vendor:) = new(event_plan:, vendor:).call

    def initialize(event_plan:, vendor:)
      @event_plan = event_plan
      @vendor = vendor
    end

    def call
      event_plan.user.with_lock("FOR NO KEY UPDATE") do
        event_plan.with_mutation_lock do
          event_plan.reload
          raise ActiveRecord::RecordNotFound unless event_plan.active?

          vendor.save! unless vendor.persisted?
          event_plan.event_plan_vendors.find_or_create_by!(vendor:)
        end
      end
    end

    private

    attr_reader :event_plan, :vendor
  end
end
