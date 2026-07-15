require "rails_helper"

RSpec.describe ContactCadencePolicy do
  let(:owner) { create(:user) }
  let(:profile) { create(:relationship_profile, user: owner) }
  let(:cadence) { build(:contact_cadence, relationship_profile: profile) }

  it "allows only the relationship owner to set and adjust cadence" do
    expect(described_class.new(owner, cadence).create?).to be(true)
    expect(described_class.new(owner, cadence).update?).to be(true)
    expect(described_class.new(create(:user), cadence).create?).to be(false)
  end
end
