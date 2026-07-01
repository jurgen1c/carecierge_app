require "rails_helper"

RSpec.describe RelationshipPreference, type: :model do
  subject(:preference) { build(:relationship_preference) }

  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:value) }

  it "allows one preference key per relationship profile case-insensitively" do
    profile = create(:relationship_profile)
    create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "decaf")
    duplicate = build(:relationship_preference, relationship_profile: profile, key: "coffee", value: "tea")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors).to be_added(:key, :taken, value: "coffee")
  end
end
