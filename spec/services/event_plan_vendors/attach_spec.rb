require "rails_helper"

RSpec.describe EventPlanVendors::Attach do
  it "serializes attachment under the event plan mutation lock" do
    plan = create(:event_plan)
    vendor = create(:vendor, user: plan.user)

    expect(plan).to receive(:with_mutation_lock).and_call_original

    expect do
      described_class.call(event_plan: plan, vendor:)
    end.to change(EventPlanVendor, :count).by(1)
  end

  it "reloads plan activity inside the lock and rejects a raced transition" do
    plan = create(:event_plan)
    vendor = create(:vendor, user: plan.user)
    allow(plan).to receive(:with_mutation_lock) do |&operation|
      plan.update_column(:status, "completed")
      operation.call
    end

    expect do
      expect do
        described_class.call(event_plan: plan, vendor:)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end.not_to change(EventPlanVendor, :count)
  end
end
