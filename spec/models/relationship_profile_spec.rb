# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  archived_at            :datetime
#  birthday               :date
#  first_name             :string           not null
#  last_name              :string
#  notes                  :text
#  preferred_name         :string
#  private_notes          :text
#  pronouns               :string
#  structured_preferences :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  relationship_type_id   :uuid
#  user_id                :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name               (first_name)
#  index_relationship_profiles_on_last_name                (last_name)
#  index_relationship_profiles_on_preferred_name           (preferred_name)
#  index_relationship_profiles_on_relationship_type_id     (relationship_type_id)
#  index_relationship_profiles_on_user_id                  (user_id)
#  index_relationship_profiles_on_user_id_and_archived_at  (user_id,archived_at)
#
# Foreign Keys
#
#  fk_rails_...                         (relationship_type_id => relationship_types.id)
#  fk_rails_...                         (user_id => users.id)
#  fk_relationship_profiles_type_owner  ([relationship_type_id, user_id] => relationship_types[id, user_id])
#
require "rails_helper"

RSpec.describe RelationshipProfile, type: :model do
  subject(:profile) { build(:relationship_profile) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:relationship_type).optional }
  it { is_expected.to have_many(:contact_methods).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_notes).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_tags).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:first_name) }

  it "requires the relationship type to belong to the same user" do
    user = create(:user)
    other_type = create(:relationship_type)
    profile = build(:relationship_profile, user:, relationship_type: other_type)

    expect(profile).not_to be_valid
    expect(profile.errors).to be_added(:relationship_type, :invalid)
  end

  it "defaults structured preferences to an empty hash" do
    expect(described_class.new.structured_preferences).to eq({})
  end

  it "reports archived state from archived_at" do
    profile = build(:relationship_profile, archived_at: Time.current)

    expect(profile).to be_archived
  end

  it "allows Ransack to search profile and relationship type fields" do
    expect(described_class.ransackable_attributes).to include("first_name", "preferred_name", "notes")
    expect(described_class.ransackable_associations).to include("relationship_type")
  end
end
