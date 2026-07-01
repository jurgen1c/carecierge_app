# == Schema Information
#
# Table name: contact_methods
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  kind                    :string           not null
#  label                   :string
#  preferred               :boolean          default(FALSE), not null
#  value                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_contact_methods_on_relationship_profile_id           (relationship_profile_id)
#  index_contact_methods_on_relationship_profile_id_and_kind  (relationship_profile_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe ContactMethod, type: :model do
  subject(:contact_method) { build(:contact_method) }

  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to validate_presence_of(:kind) }
  it { is_expected.to validate_presence_of(:value) }

  it "defines contact kinds as a Rails enum" do
    expect(described_class.defined_enums["kind"]).to eq(
      "email" => "email",
      "personal_email" => "personal_email",
      "business_email" => "business_email",
      "phone" => "phone",
      "personal_phone" => "personal_phone",
      "business_phone" => "business_phone"
    )
  end

  it "allows one contact method per kind for each relationship profile" do
    profile = create(:relationship_profile)
    create(:contact_method, relationship_profile: profile, kind: "email")
    duplicate = build(:contact_method, relationship_profile: profile, kind: "email")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors).to be_added(:kind, :taken, value: "email")
  end
end
