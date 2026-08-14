require "rails_helper"

# == Schema Information
#
# Table name: social_context_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  allow_suggestions       :boolean          default(FALSE), not null
#  analyzed_at             :datetime
#  interpretation          :text
#  interpretation_status   :string           default("not_requested"), not null
#  lock_version            :integer          default(0), not null
#  suggested_uses          :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_created_at_71f3ad1154        (relationship_profile_id,created_at)
#  index_social_context_notes_on_profile_and_suggestion_usage  (relationship_profile_id,allow_suggestions)
#  index_social_context_notes_on_relationship_profile_id       (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
RSpec.describe SocialContextNote do
  it "belongs to one relationship and keeps downstream use off by default" do
    note = described_class.create!(
      relationship_profile: create(:relationship_profile),
      body: "Maya posted about a neighborhood bookshop."
    )

    expect(note).to have_attributes(
      allow_suggestions: false,
      interpretation_status: "not_requested",
      suggested_uses: []
    )
    expect(note.body.to_plain_text).to include("neighborhood bookshop")
  end

  it "requires user-authored text and bounds retained content" do
    note = build(:social_context_note, body: "")

    expect(note).not_to be_valid
    expect(note.errors[:body]).to be_present

    note.body = "A" * (described_class::MAX_BODY_CHARACTERS + 1)
    expect(note).not_to be_valid
  end

  it "treats an omitted rich-text body as invalid instead of raising" do
    note = build(:social_context_note)
    note.body = nil

    expect { note.valid? }.not_to raise_error
    expect(note).not_to be_valid
    expect(note.errors[:body]).to be_present
  end

  it "accepts a bounded screenshot and rejects unsupported embedded files" do
    note = build(:social_context_note)
    image = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("small image"),
      filename: "social-context.png",
      content_type: "image/png"
    )
    note.body = "<p>Bookshop post</p>#{ActionText::Attachment.from_attachable(image).to_html}"

    expect(note).to be_valid
    expect(note.image_blobs).to contain_exactly(image)

    document = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("not an image"),
      filename: "social-context.txt",
      content_type: "text/plain"
    )
    note.body = "<p>Bookshop post</p>#{ActionText::Attachment.from_attachable(document).to_html}"

    expect(note).not_to be_valid
    expect(note.errors[:body]).to be_present
  end

  it "rejects images that are not managed Active Storage attachments" do
    remote_image = build(
      :social_context_note,
      body: '<p>Bookshop post</p><img src="https://example.com/tracker.png">'
    )
    inline_image = build(
      :social_context_note,
      body: "<p>Bookshop post</p><img src=\"data:image/png;base64,#{'A' * (described_class::MAX_BODY_HTML_BYTES + 1)}\">"
    )

    expect(remote_image).not_to be_valid
    expect(remote_image.errors.details[:body]).to include(error: :unmanaged_image)
    expect(inline_image).not_to be_valid
    expect(inline_image.errors.details[:body]).to include(error: :html_too_large, count: described_class::MAX_BODY_HTML_BYTES)
  end

  it "exposes only approved, opted-in context to downstream consumers" do
    note = create(
      :social_context_note,
      body: "Maya posted about an upcoming bookstore event.",
      interpretation: "The event may be a comfortable conversation topic.",
      interpretation_status: "draft",
      suggested_uses: %w[message conversation_topic],
      allow_suggestions: true
    )

    expect(note.downstream_context).to include("upcoming bookstore event")
    expect(note.downstream_context).not_to include("may be a comfortable conversation topic")

    note.update!(interpretation_status: "approved")

    expect(note.downstream_context).to include(
      "upcoming bookstore event",
      "may be a comfortable conversation topic"
    )
  end

  it "rejects unsupported suggested uses and interpretation states" do
    note = build(:social_context_note, suggested_uses: [ "profile_score" ], interpretation_status: "trusted_fact")

    expect(note).not_to be_valid
    expect(note.errors[:suggested_uses]).to be_present
    expect(note.errors[:interpretation_status]).to be_present
  end

  it "rejects repeated or oversized suggested-use metadata" do
    repeated = build(:social_context_note, suggested_uses: %w[gift gift])
    oversized = build(:social_context_note, suggested_uses: SocialContextNote::SUGGESTED_USES + [ "gift" ])

    expect(repeated).not_to be_valid
    expect(oversized).not_to be_valid
    expect(repeated.errors[:suggested_uses]).to be_present
    expect(oversized.errors[:suggested_uses]).to be_present
  end

  it "cannot approve an interpretation from the prior source while changing the user note" do
    note = create(
      :social_context_note,
      body: "Original social context.",
      interpretation: "An interpretation of the original source.",
      interpretation_status: "draft",
      suggested_uses: %w[message]
    )

    note.update_from_user!(
      {
        body: "Materially different social context.",
        interpretation: "An interpretation of the original source.",
        suggested_uses: %w[gift]
      },
      approve_interpretation: true
    )

    expect(note).to have_attributes(
      interpretation: nil,
      interpretation_status: "not_requested",
      suggested_uses: []
    )
  end

  it "reviews suggested uses with the interpretation and clears them when the interpretation is removed" do
    note = create(
      :social_context_note,
      interpretation: "A bookstore visit may be timely.",
      interpretation_status: "draft",
      suggested_uses: %w[gift message],
      allow_suggestions: true
    )

    note.update_from_user!(
      {
        interpretation: "A bookstore conversation may be timely.",
        suggested_uses: %w[conversation_topic]
      },
      approve_interpretation: true
    )

    expect(note).to have_attributes(
      interpretation_status: "approved",
      suggested_uses: %w[conversation_topic]
    )

    note.update_from_user!({ interpretation: "", suggested_uses: %w[gift] })

    expect(note).to have_attributes(
      interpretation: nil,
      interpretation_status: "not_requested",
      suggested_uses: [],
      analyzed_at: nil
    )
  end

  it "does not create user context after the relationship is archived" do
    profile = create(:relationship_profile)
    note = build(:social_context_note, relationship_profile: profile)
    profile.update!(discarded_at: Time.current)

    expect { note.save_from_user }.to raise_error(ActiveRecord::RecordNotFound)
    expect(note).not_to be_persisted
  end

  it "does not update user context after the relationship is archived" do
    profile = create(:relationship_profile)
    note = create(:social_context_note, relationship_profile: profile)
    profile.update!(discarded_at: Time.current)

    expect do
      note.update_from_user!({ body: "Context saved after archival" })
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(note.reload.body.to_plain_text).not_to include("Context saved after archival")
  end

  it "does not destroy user context after the relationship is archived" do
    profile = create(:relationship_profile)
    note = create(:social_context_note, relationship_profile: profile)
    profile.update!(discarded_at: Time.current)

    expect { note.destroy_from_user! }.to raise_error(ActiveRecord::RecordNotFound)
    expect(described_class.exists?(note.id)).to be(true)
  end
end
