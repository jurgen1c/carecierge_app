require "rails_helper"

RSpec.describe ReminderPolicy do
  let(:owner) { create(:user) }
  let(:reminder) { create(:reminder, user: owner, relationship_profile: create(:relationship_profile, user: owner)) }

  it "allows the owner to manage, act on, and export reminders" do
    policy = described_class.new(owner, reminder)

    expect(policy.index?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
    expect(policy.snooze?).to be(true)
    expect(policy.complete?).to be(true)
    expect(policy.calendar?).to be(true)
    expect(described_class::Scope.new(owner, Reminder).resolve).to contain_exactly(reminder)
  end

  it "denies another user and excludes the reminder from their scope" do
    other_user = create(:user)
    policy = described_class.new(other_user, reminder)

    expect(policy.update?).to be(false)
    expect(policy.snooze?).to be(false)
    expect(policy.complete?).to be(false)
    expect(policy.calendar?).to be(false)
    expect(described_class::Scope.new(other_user, Reminder).resolve).to be_empty
  end

  it "denies creating a reminder assigned to another user" do
    forged_reminder = build(:reminder, user: create(:user))

    expect(described_class.new(owner, forged_reminder).create?).to be(false)
  end
end
