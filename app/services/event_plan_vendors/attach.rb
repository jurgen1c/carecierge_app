module EventPlanVendors
  class Attach
    def self.call(event_plan:, vendor:) = new(event_plan:, vendor:).call

    def initialize(event_plan:, vendor:)
      @event_plan = event_plan
      @vendor = vendor
    end

    def call
      persisted_vendor_id = vendor.id if vendor.persisted?

      event_plan.user.with_lock("FOR NO KEY UPDATE") do
        event_plan.with_mutation_lock do
          event_plan.reload
          raise ActiveRecord::RecordNotFound unless event_plan.active?

          vendor.save! unless persisted_vendor_id
          attached_vendor = persisted_vendor_id ? event_plan.user.vendors.lock.find(persisted_vendor_id) : vendor
          event_plan.event_plan_vendors.find_or_create_by!(vendor: attached_vendor)
        end
      end
    end

    private

    attr_reader :event_plan, :vendor
  end
end
