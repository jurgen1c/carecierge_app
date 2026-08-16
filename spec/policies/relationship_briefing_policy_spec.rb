require "rails_helper"

RSpec.describe RelationshipBriefingPolicy do
  subject(:policy) { described_class.new(user, briefing) }

  let(:user) { create(:user) }
  let(:briefing) { create(:relationship_briefing, user:, relationship_profile: create(:relationship_profile, user:)) }

  it "allows the owner to save and dismiss" do
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
  end

  context "when another user owns the briefing" do
    let(:briefing) { create(:relationship_briefing) }

    it "denies mutation" do
      expect(policy.update?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end
end
