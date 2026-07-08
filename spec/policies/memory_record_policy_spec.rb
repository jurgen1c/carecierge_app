require "rails_helper"

RSpec.describe MemoryRecordPolicy do
  let(:owner) { create(:user) }
  let(:profile) { create(:relationship_profile, user: owner) }
  let(:record) { create(:memory_record, relationship_profile: profile) }

  context "with the relationship profile owner" do
    subject(:policy) { described_class.new(owner, record) }

    it "allows record management and resolves owned records" do
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)
      expect(policy.review?).to be(true)
      expect(policy.approve_high_impact_automation?).to be(true)
      expect(policy.destroy?).to be(true)
      expect(described_class::Scope.new(owner, MemoryRecord).resolve).to contain_exactly(record)
    end
  end

  context "with another user" do
    let(:other_user) { create(:user) }

    subject(:policy) { described_class.new(other_user, record) }

    it "denies record management and resolves no records" do
      expect(policy.update?).to be(false)
      expect(policy.review?).to be(false)
      expect(policy.approve_high_impact_automation?).to be(false)
      expect(policy.destroy?).to be(false)
      expect(described_class::Scope.new(other_user, MemoryRecord).resolve).to be_empty
    end
  end

  context "without a user" do
    subject(:policy) { described_class.new(nil, record) }

    it "denies record management and resolves no records" do
      expect(policy.update?).to be_falsey
      expect(described_class::Scope.new(nil, MemoryRecord).resolve).to be_empty
    end
  end
end
