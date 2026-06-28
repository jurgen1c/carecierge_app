# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  birthday               :date
#  discarded_at           :datetime
#  first_name             :string           not null
#  last_name              :string
#  notes                  :text
#  preferred_name         :string
#  private_notes          :text
#  pronouns               :string
#  slug                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name               (first_name)
#  index_relationship_profiles_on_last_name                (last_name)
#  index_relationship_profiles_on_preferred_name           (preferred_name)
#  index_relationship_profiles_on_slug                    (slug) UNIQUE
#  index_relationship_profiles_on_user_id                  (user_id)
#  index_relationship_profiles_on_user_id_and_discarded_at (user_id,discarded_at)
#
# Foreign Keys
#
#  fk_rails_...                         (user_id => users.id)
#
require "rails_helper"

RSpec.describe RelationshipProfile, type: :model do
  subject(:profile) { build(:relationship_profile) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:contact_methods).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_notes).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_preferences).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_tags).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:first_name) }

  it "uses friendly profile names for user-facing routes" do
    profile = create(:relationship_profile, first_name: "Maya", last_name: "Rivera")

    expect(profile.to_param).to start_with("maya-rivera")
    expect(described_class.friendly.find(profile.to_param)).to eq(profile)
  end

  it "reports archived state from discard timestamps" do
    profile = create(:relationship_profile)

    profile.archive!

    expect(profile).to be_discarded
    expect(profile).to be_archived
  end

  it "exposes associated preferences as a keyed hash" do
    profile = create(:relationship_profile)
    create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "decaf")
    create(:relationship_preference, relationship_profile: profile, key: "Topics", value: "books")

    expect(profile.structured_preferences).to eq("Coffee" => "decaf", "Topics" => "books")
    expect(profile.structured_preferences_text).to eq("Coffee: decaf\nTopics: books")
  end

  it "allows Ransack to search profile and relationship type fields" do
    expect(described_class.ransackable_attributes).to include("first_name", "preferred_name", "notes", "relationship_type_name")
  end
end
