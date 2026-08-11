require "rails_helper"

# == Schema Information
#
# Table name: message_drafts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  draft_type              :string           not null
#  tone                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_message_drafts_on_relationship_profile_id  (relationship_profile_id) UNIQUE
#  index_message_drafts_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe MessageDraft, type: :model do
  it "supports the documented draft types and tones" do
    expect(described_class::DRAFT_TYPES).to contain_exactly(
      "birthday",
      "apology",
      "thank_you",
      "check_in",
      "congratulations",
      "condolence",
      "professional_follow_up",
      "invitation",
      "boundary_setting"
    )
    expect(described_class::TONES).to contain_exactly(
      "warm",
      "funny",
      "romantic",
      "professional",
      "concise",
      "emotional",
      "apologetic",
      "casual",
      "formal",
      "encouraging"
    )
  end

  it "rejects a relationship profile owned by another account" do
    draft = build(:message_draft, user: create(:user), relationship_profile: create(:relationship_profile))

    expect(draft).not_to be_valid
    expect(draft.errors.of_kind?(:relationship_profile, :owner_mismatch)).to be(true)
  end

  it "appends immutable revisions and exposes the latest revision" do
    draft = create(:message_draft)

    first = draft.append_revision!(content: "First version", origin: "generated", context_categories: %w[profile])
    second = draft.append_revision!(content: "Second version", origin: "edited")

    expect([ first.position, second.position ]).to eq([ 1, 2 ])
    expect(draft.current_revision).to eq(second)
  end

  it "restores an earlier revision as a new immutable revision" do
    draft = create(:message_draft)
    original = draft.append_revision!(content: "Original", origin: "generated")
    draft.append_revision!(content: "Edited", origin: "edited")

    restored = draft.restore_revision!(original)

    expect(restored).to have_attributes(position: 3, origin: "restored", content: "Original")
    expect(draft.draft_revisions.count).to eq(3)
  end

  it "rejects a stale edit after the relationship profile is archived" do
    profile = create(:relationship_profile)
    draft = create(:message_draft, user: profile.user, relationship_profile: profile)
    create(:draft_revision, message_draft: draft, position: 1)
    stale_draft = described_class.find(draft.id)
    stale_draft.relationship_profile
    profile.archive!

    expect do
      stale_draft.save_edit!(content: "Written after archive", draft_type: "birthday", tone: "warm")
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(draft.draft_revisions.count).to eq(1)
  end

  it "rejects a stale restore after the relationship profile is archived" do
    profile = create(:relationship_profile)
    draft = create(:message_draft, user: profile.user, relationship_profile: profile)
    revision = create(:draft_revision, message_draft: draft, position: 1)
    stale_draft = described_class.find(draft.id)
    stale_draft.relationship_profile
    profile.archive!

    expect { stale_draft.restore_revision!(revision) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(draft.draft_revisions.count).to eq(1)
  end
end
