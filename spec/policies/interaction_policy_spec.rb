require "rails_helper"

RSpec.describe InteractionPolicy do
  let(:owner) { create(:user) }
  let(:profile) { create(:relationship_profile, user: owner) }

  it "allows the owner to manage manual interactions" do
    interaction = create(:interaction, relationship_profile: profile)
    policy = described_class.new(owner, interaction)

    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
  end

  it "prevents generic mutation of derived interactions" do
    interaction = create(:interaction, :derived_from_conversation_recap, relationship_profile: profile, source: create(:conversation_recap, relationship_profile: profile))
    policy = described_class.new(owner, interaction)

    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
  end

  it "denies another user and excludes the interaction from their scope" do
    interaction = create(:interaction, relationship_profile: profile)
    other_user = create(:user)
    policy = described_class.new(other_user, interaction)

    expect(policy.create?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
    expect(described_class::Scope.new(other_user, Interaction).resolve).to be_empty
  end
end
