# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  birthday           :date
#  discarded_at       :datetime
#  first_name         :string           not null
#  last_name          :string
#  preferred_name     :string
#  profile_attributes :jsonb            not null
#  pronouns           :string
#  slug               :string
#  type               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :uuid             not null
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
  it { is_expected.to have_many(:relationship_taggings).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_tags).through(:relationship_taggings) }
  it { is_expected.to have_many(:relationship_group_memberships).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_groups).through(:relationship_group_memberships) }
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
    profile.relationship_taggings.build(tag_name: "garden")
    profile.relationship_taggings.build(tag_name: " Garden ")

    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_tags]).to include("contains duplicate names")
  end

  it "validates duplicate nested group names before hitting database constraints" do
    profile = build(:relationship_profile)
    profile.relationship_group_memberships.build(group_name: "college friends")
    profile.relationship_group_memberships.build(group_name: " College Friends ")

    expect(profile).not_to be_valid
    expect(profile.errors[:relationship_groups]).to include("contains duplicate names")
  end

  it "destroys tag and group memberships while preserving reusable catalog entries" do
    profile = create(:relationship_profile)
    tag = create(:relationship_tag, user: profile.user, name: "Garden")
    group = create(:relationship_group, user: profile.user, name: "Family")
    create(:relationship_tagging, relationship_profile: profile, relationship_tag: tag)
    create(:relationship_group_membership, relationship_profile: profile, relationship_group: group)

    expect do
      profile.destroy!
    end.to change(RelationshipTagging, :count).by(-1)
      .and change(RelationshipGroupMembership, :count).by(-1)
      .and change(RelationshipTag, :count).by(0)
      .and change(RelationshipGroup, :count).by(0)
  end

  it "switches reusable tag and group assignments when submitted names change" do
    profile = create(:relationship_profile)
    tag = create(:relationship_tag, user: profile.user, name: "Family")
    group = create(:relationship_group, user: profile.user, name: "Neighbors")
    create(:relationship_tagging, relationship_profile: profile, relationship_tag: tag)
    create(:relationship_group_membership, relationship_profile: profile, relationship_group: group)

    profile.update!(
      relationship_tags_attributes: { "0" => { id: tag.id, name: "VIP" } },
      relationship_groups_attributes: { "0" => { id: group.id, name: "Work" } }
    )

    expect(profile.reload.relationship_tags.pluck(:name)).to contain_exactly("VIP")
    expect(profile.relationship_groups.pluck(:name)).to contain_exactly("Work")
    expect(profile.user.relationship_tags.pluck(:name)).to include("Family", "VIP")
    expect(profile.user.relationship_groups.pluck(:name)).to include("Neighbors", "Work")
  end

  it "treats invalid nested tag and group ids as name-based assignments" do
    profile = create(:relationship_profile)

    expect do
      profile.update!(
        relationship_tags_attributes: { "0" => { id: SecureRandom.uuid, name: "VIP" } },
        relationship_groups_attributes: { "0" => { id: SecureRandom.uuid, name: "Work" } }
      )
    end.to change(RelationshipTag, :count).by(1)
      .and change(RelationshipGroup, :count).by(1)

    expect(profile.reload.relationship_tags.pluck(:name)).to contain_exactly("VIP")
    expect(profile.relationship_groups.pluck(:name)).to contain_exactly("Work")
  end

  it "does not query relationship assignments for no-op cleanup on ordinary saves" do
    profile = create(:relationship_profile)

    sql = capture_sql { profile.update!(preferred_name: "May") }

    expect(sql.grep(/DELETE FROM "relationship_taggings"|DELETE FROM "relationship_group_memberships"/)).to be_empty
  end

  it "does not validate independently managed gifts when saving the profile" do
    profile = create(:relationship_profile)
    legacy_gift = build(:gift, relationship_profile: profile, status: "given", given_on: nil, name: "Legacy gift")
    legacy_gift.save!(validate: false)

    profile.reload.gifts.load

    expect(profile.update(preferred_name: "May")).to be(true)
  end

  it "bulk deletes marked relationship assignments during post-save cleanup" do
    profile = build(:relationship_profile)
    tag_ids = [ SecureRandom.uuid ]
    group_ids = [ SecureRandom.uuid ]
    tag_scope = instance_double(ActiveRecord::Relation)
    group_scope = instance_double(ActiveRecord::Relation)

    profile.send(:marked_relationship_assignment_ids)[:relationship_tag].concat(tag_ids)
    profile.send(:marked_relationship_assignment_ids)[:relationship_group].concat(group_ids)

    expect(RelationshipTagging).to receive(:where).with(id: tag_ids).and_return(tag_scope)
    expect(tag_scope).to receive(:delete_all)
    expect(RelationshipGroupMembership).to receive(:where).with(id: group_ids).and_return(group_scope)
    expect(group_scope).to receive(:delete_all)

    profile.send(:destroy_marked_relationship_assignments)
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

  it "uses jsonb-backed custom labels for other relationship types" do
    profile = create(:relationship_profile, type: "RelationshipProfiles::Other", custom_type_label: "College roommate")

    expect(profile.reload.profile_attributes).to eq("custom_type_label" => "College roommate")
    expect(profile.relationship_type_label).to eq("College roommate")
  end

  it "clears custom relationship labels for concrete STI types" do
    profile = create(:relationship_profile, type: "RelationshipProfiles::Friend", custom_type_label: "College roommate")

    expect(profile.reload.custom_type_label).to be_nil
    expect(profile.profile_attributes).to eq({})
    expect(profile.relationship_type_label).to eq("Friend")
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

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }

    queries
  end
end
