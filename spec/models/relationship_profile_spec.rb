# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id             :uuid             not null, primary key
#  birthday       :date
#  discarded_at   :datetime
#  first_name     :string           not null
#  last_name      :string
#  preferred_name :string
#  pronouns       :string
#  slug           :string
#  type           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name                (first_name)
#  index_relationship_profiles_on_last_name                 (last_name)
#  index_relationship_profiles_on_preferred_name            (preferred_name)
#  index_relationship_profiles_on_slug                      (slug) UNIQUE
#  index_relationship_profiles_on_type                      (type)
#  index_relationship_profiles_on_user_id                   (user_id)
#  index_relationship_profiles_on_user_id_and_discarded_at  (user_id,discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
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
    expect(described_class.friendly.find(profile.to_param).id).to eq(profile.id)
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

    expect(profile.reload.structured_preferences).to eq("Coffee" => "decaf", "Topics" => "books")
    expect(profile.structured_preferences_text).to eq("Coffee: decaf\nTopics: books")
  end

  it "stores notes as associated rich text relationship notes" do
    profile = create(:relationship_profile)
    note = create(:relationship_note, relationship_profile: profile, body: "<p>Bring <strong>tea</strong>.</p>")

    expect(note.body.to_plain_text).to include("Bring tea.")
    expect(profile.reload.public_notes).to contain_exactly(note)
    expect(RelationshipNote.reflect_on_association(:rich_text_body)).to be_present
  end

  it "uses STI types as the relationship type source for forms" do
    profile = create(:relationship_profile, type: "MentorRelationshipProfile")

    reloaded_profile = described_class.find(profile.id)

    expect(reloaded_profile).to be_a(MentorRelationshipProfile)
    expect(reloaded_profile.relationship_type_label).to eq("Mentor")
    expect(described_class.type_options).to include([ "Friend", "FriendRelationshipProfile" ])
  end

  it "localizes relationship type labels" do
    profile = build(:relationship_profile, type: "BestFriendRelationshipProfile")

    I18n.with_locale(:es) do
      expect(profile.relationship_type_label).to eq("Mejor amigo")
      expect(described_class.type_options).to include([ "Mejor amigo", "BestFriendRelationshipProfile" ])
    end
  end

  it "offers common family, romantic, work, and social STI relationship types" do
    expect(described_class.type_options).to include(
      [ "Friend", "FriendRelationshipProfile" ],
      [ "Spouse", "SpouseRelationshipProfile" ],
      [ "Partner", "PartnerRelationshipProfile" ],
      [ "Boss", "BossRelationshipProfile" ],
      [ "Mother", "MotherRelationshipProfile" ],
      [ "Other", "OtherRelationshipProfile" ]
    )
  end

  it "maps every configured relationship type to a concrete STI subclass" do
    described_class.type_options.each do |_label, class_name|
      expect(class_name.constantize).to be < described_class
    end
  end

  it "allows Ransack to search profile and relationship type fields" do
    expect(described_class.ransackable_attributes).to include("first_name", "preferred_name", "type")
  end
end
