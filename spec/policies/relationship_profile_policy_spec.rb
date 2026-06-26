require "rails_helper"

RSpec.describe RelationshipProfilePolicy do
  subject(:policy) { described_class.new(user, profile) }

  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  it "permits owners to manage their relationship profiles" do
    expect(policy.index?).to be(true)
    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)
    expect(policy.archive?).to be(true)
  end

  it "denies access to another user's relationship profile" do
    other_profile = create(:relationship_profile)
    policy = described_class.new(user, other_profile)

    expect(policy.show?).to be(false)
    expect(policy.update?).to be(false)
    expect(policy.destroy?).to be(false)
    expect(policy.archive?).to be(false)
  end

  it "scopes records to the signed-in owner" do
    visible = create(:relationship_profile, user:)
    hidden = create(:relationship_profile)

    resolved = described_class::Scope.new(user, RelationshipProfile.all).resolve

    expect(resolved).to include(visible)
    expect(resolved).not_to include(hidden)
  end
end
