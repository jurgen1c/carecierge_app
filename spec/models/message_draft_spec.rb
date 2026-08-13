require "rails_helper"

# == Schema Information
#
# Table name: message_drafts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  draft_type              :string           not null
#  formality               :string           default("balanced"), not null
#  response_length         :string           default("medium"), not null
#  situation               :text             default(""), not null
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
  it "supports the documented purposes, tones, response lengths, and formalities" do
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
      "encouraging"
    )
    expect(described_class::RESPONSE_LENGTHS).to contain_exactly("short", "medium", "long")
    expect(described_class::FORMALITIES).to contain_exactly("casual", "balanced", "formal")
  end

  it "keeps late legacy formality tones valid during the rolling-deploy compatibility window" do
    draft = create(:message_draft)
    draft.update_column(:tone, "casual")

    expect(draft.reload).to be_valid
    expect(draft.effective_tone).to eq("warm")
    expect(draft.effective_formality).to eq("casual")
  end

  it "does not retain inferred formality after an old process changes its tone" do
    draft = create(:message_draft, tone: "formal", formality: "balanced")

    expect(draft.effective_formality).to eq("formal")

    draft.update_column(:tone, "encouraging")

    expect(draft.reload.effective_tone).to eq("encouraging")
    expect(draft.effective_formality).to eq("balanced")
  end

  it "preserves response settings omitted by a stale edit client under the draft lock" do
    draft = create(:message_draft, situation: "Earlier message", response_length: "short", formality: "casual")
    create(:draft_revision, message_draft: draft, position: 1)
    stale_draft = described_class.find(draft.id)
    draft.update!(situation: "New message", response_length: "long", formality: "formal")

    stale_draft.save_edit!(content: "Edited response", draft_type: "check_in", tone: "warm")

    expect(draft.reload).to have_attributes(
      situation: "New message",
      response_length: "long",
      formality: "formal"
    )
  end

  it "normalizes and bounds the private message or situation" do
    draft = build(:message_draft, situation: "  Maya asked whether I can attend.  ")

    expect(draft).to be_valid
    expect(draft.situation).to eq("Maya asked whether I can attend.")

    draft.situation = "x" * (described_class::MAX_SITUATION_LENGTH + 1)

    expect(draft).not_to be_valid
    expect(draft.errors.of_kind?(:situation, :too_long)).to be(true)
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
      stale_draft.save_edit!(
        content: "Written after archive",
        draft_type: "birthday",
        tone: "warm",
        situation: "A birthday reply",
        response_length: "short",
        formality: "casual"
      )
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(draft.draft_revisions.count).to eq(1)
  end


  it "persists response settings when an edit becomes a new revision" do
    draft = create(:message_draft)
    create(:draft_revision, message_draft: draft, position: 1)

    draft.save_edit!(
      content: "I would be glad to join you.",
      draft_type: "invitation",
      tone: "warm",
      situation: "Maya invited me to dinner.",
      response_length: "short",
      formality: "casual"
    )

    expect(draft.reload).to have_attributes(
      draft_type: "invitation",
      tone: "warm",
      situation: "Maya invited me to dinner.",
      response_length: "short",
      formality: "casual"
    )
    expect(draft.current_revision).to have_attributes(origin: "edited", content: "I would be glad to join you.")
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
