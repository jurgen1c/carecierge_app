require "rails_helper"

RSpec.describe PrivacyVaultItemPolicy do
  subject(:policy) { described_class.new(user, item) }

  let(:user) { create(:user) }
  let(:item) { create(:privacy_vault_item, relationship_profile: create(:relationship_profile, user:)) }

  it "permits only the relationship owner" do
    expect(policy.show?).to be(true)
    expect(policy.create?).to be(true)
    expect(policy.update?).to be(true)
    expect(policy.destroy?).to be(true)

    other_policy = described_class.new(create(:user), item)
    expect(other_policy.show?).to be(false)
    expect(other_policy.create?).to be(false)
    expect(other_policy.update?).to be(false)
    expect(other_policy.destroy?).to be(false)
  end
end
