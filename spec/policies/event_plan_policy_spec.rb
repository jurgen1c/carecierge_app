require "rails_helper"

RSpec.describe EventPlanPolicy do
  subject(:policy) { described_class.new(user, event_plan) }

  let(:event_plan) { create(:event_plan) }

  context "when the plan belongs to the user" do
    let(:user) { event_plan.user }

    it "permits owner actions" do
      expect(%i[show create update destroy suggest complete reopen]).to all(satisfy { |action| policy.public_send("#{action}?") })
    end
  end

  context "when the plan belongs to another user" do
    let(:user) { create(:user) }

    it "forbids foreign actions" do
      expect(%i[show create update destroy suggest complete reopen]).to all(satisfy { |action| !policy.public_send("#{action}?") })
    end
  end

  it "scopes plans to their owner" do
    owned = create(:event_plan)
    create(:event_plan)

    expect(described_class::Scope.new(owned.user, EventPlan).resolve).to contain_exactly(owned)
  end
end
