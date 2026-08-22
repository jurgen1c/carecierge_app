require "rails_helper"

RSpec.describe PlanTaskPolicy do
  subject(:policy) { described_class.new(user, plan_task) }

  let(:plan_task) { create(:plan_task) }

  context "when the task belongs to the user's plan" do
    let(:user) { plan_task.event_plan.user }

    it "permits owner actions" do
      expect(%i[create update destroy complete reopen]).to all(satisfy { |action| policy.public_send("#{action}?") })
    end
  end

  context "when the task belongs to another user" do
    let(:user) { create(:user) }

    it "forbids foreign actions" do
      expect(%i[create update destroy complete reopen]).to all(satisfy { |action| !policy.public_send("#{action}?") })
    end
  end
end
