require "rails_helper"

RSpec.describe EventPlanVendors::Detach do
  it "serializes detachment under the event plan mutation lock" do
    assignment = create(:event_plan_vendor)
    plan = assignment.event_plan

    expect(plan).to receive(:with_mutation_lock).and_call_original

    expect do
      described_class.call(event_plan: plan, assignment:)
    end.to change(EventPlanVendor, :count).by(-1)
  end

  it "reloads plan activity inside the lock and rejects a raced transition" do
    assignment = create(:event_plan_vendor)
    plan = assignment.event_plan
    allow(plan).to receive(:with_mutation_lock) do |&operation|
      plan.update_column(:status, "completed")
      operation.call
    end

    expect do
      expect do
        described_class.call(event_plan: plan, assignment:)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end.not_to change(EventPlanVendor, :count)
  end
end
