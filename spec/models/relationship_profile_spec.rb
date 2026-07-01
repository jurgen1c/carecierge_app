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
  it { is_expected.to have_many(:relationship_field_values).dependent(:destroy) }
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

  it "validates duplicate nested contact kinds before hitting database constraints" do
    profile = build(:relationship_profile)
    profile.contact_methods.build(kind: "email", value: "maya@example.com")
    profile.contact_methods.build(kind: "email", value: "maya.alt@example.com")

    expect(profile).not_to be_valid
    expect(profile.errors[:contact_methods]).to include("contains duplicate kinds")
  end

  it "validates duplicate nested preference keys before hitting database constraints" do
    profile = build(:relationship_profile)
    profile.relationship_preferences.build(key: "Coffee", value: "decaf")
    profile.relationship_preferences.build(key: " coffee ", value: "regular")

    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_preferences]).to include("contains duplicate keys")
  end

  it "validates duplicate nested tag names before hitting database constraints" do
    profile = build(:relationship_profile)
    profile.relationship_tags.build(name: "garden")
    profile.relationship_tags.build(name: " Garden ")

    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_tags]).to include("contains duplicate names")
  end

  it "stores notes as associated rich text relationship notes" do
    profile = create(:relationship_profile)
    note = create(:relationship_note, relationship_profile: profile, body: "<p>Bring <strong>tea</strong>.</p>")

    expect(note.body.to_plain_text).to include("Bring tea.")
    expect(profile.reload.public_notes).to contain_exactly(note)
    expect(RelationshipNote.reflect_on_association(:rich_text_body)).to be_present
  end

  it "uses STI types as the relationship type source for forms" do
    profile = create(:relationship_profile, type: "RelationshipProfiles::Mentor")

    reloaded_profile = described_class.find(profile.id)

    expect(reloaded_profile).to be_a(RelationshipProfiles::Mentor)
    expect(reloaded_profile.relationship_type_label).to eq("Mentor")
    expect(described_class.type_options).to include([ "Friend", "RelationshipProfiles::Friend" ])
  end

  it "localizes relationship type labels" do
    profile = build(:relationship_profile, type: "RelationshipProfiles::BestFriend")

    I18n.with_locale(:es) do
      expect(profile.relationship_type_label).to eq("Mejor amigo")
      expect(described_class.type_options).to include([ "Mejor amigo", "RelationshipProfiles::BestFriend" ])
    end
  end

  it "offers common family, romantic, work, and social STI relationship types" do
    expect(described_class.type_options).to include(
      [ "Friend", "RelationshipProfiles::Friend" ],
      [ "Spouse", "RelationshipProfiles::Spouse" ],
      [ "Partner", "RelationshipProfiles::Partner" ],
      [ "Boss", "RelationshipProfiles::Boss" ],
      [ "Mother", "RelationshipProfiles::Mother" ],
      [ "Other", "RelationshipProfiles::Other" ]
    )
  end

  it "maps every configured relationship type to a concrete STI subclass" do
    described_class.type_options.each do |_label, class_name|
      expect(class_name.constantize).to be < described_class
    end
  end

  it "validates duplicate nested custom field labels before hitting database constraints" do
    profile = build(:relationship_profile)
    profile.relationship_field_values.build(label: "Favorite snack", value: "mango", custom: true)
    profile.relationship_field_values.build(label: " favorite snack ", value: "berries", custom: true)

    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_field_values]).to include("have duplicate labels")
  end

  it "validates duplicate nested template fields before hitting database constraints" do
    field = create(:template_field)
    profile = build(:relationship_profile)
    profile.relationship_field_values.build(template_field: field, label: field.label, value: "mango")
    profile.relationship_field_values.build(template_field: field, label: field.label, value: "berries")

    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_field_values]).to include("have duplicate suggested fields")
  end

  it "allows Ransack to search profile and relationship type fields" do
    expect(described_class.ransackable_attributes).to include("first_name", "preferred_name", "type")
  end
end
