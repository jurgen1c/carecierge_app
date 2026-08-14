require "rails_helper"

RSpec.describe SocialContextNotes::Analyze do
  it "stores a reviewable draft and privacy-minimized audit evidence" do
    user = create(:user)
    note = create(:social_context_note, relationship_profile: create(:relationship_profile, user:))
    analyzer = double
    expect(analyzer).to receive(:analyze).with(
      input: have_attributes(text: a_string_including("neighborhood bookshop"), image_blob_ids: []),
      locale: :en
    ).and_return(
      interpretation: "This may be a useful conversation topic.",
      suggested_uses: %w[conversation_topic]
    )

    described_class.call(actor: user, note:, expected_lock_version: note.lock_version, analyzer:, locale: :en)

    expect(note.reload).to have_attributes(
      interpretation: "This may be a useful conversation topic.",
      interpretation_status: "draft",
      suggested_uses: %w[conversation_topic]
    )
    expect(note.analyzed_at).to be_present
    event = AuditEvent.find_by!(user:, action: "automation.performed", target: note.relationship_profile)
    expect(event.metadata).to eq(
      "capability" => "analyze_uploaded_social_content",
      "result" => "draft_created"
    )
    expect(event.to_json).not_to include("conversation topic")
  end

  it "does not persist a stale result after the note changes during analysis" do
    user = create(:user)
    note = create(:social_context_note, relationship_profile: create(:relationship_profile, user:))
    analyzer = double
    allow(analyzer).to receive(:analyze) do |input:, **|
      expect(input.text).to include("neighborhood bookshop")
      note.update!(allow_suggestions: true)
      { interpretation: "Late result", suggested_uses: %w[message] }
    end

    expect do
      described_class.call(actor: user, note:, expected_lock_version: note.lock_version, analyzer:)
    end.to raise_error(ActiveRecord::StaleObjectError)

    expect(note.reload.interpretation).to be_nil
  end

  it "fails closed when the profile is archived while analysis is in flight" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile)
    analyzer = double
    allow(analyzer).to receive(:analyze) do |input:, **|
      expect(input.text).to include("neighborhood bookshop")
      profile.update!(discarded_at: Time.current)
      { interpretation: "Late result", suggested_uses: %w[message] }
    end

    expect do
      described_class.call(actor: user, note:, expected_lock_version: note.lock_version, analyzer:)
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(note.reload.interpretation).to be_nil
  end

  it "analyzes the immutable source revision explicitly submitted by the user" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    original_image = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("original image"),
      filename: "original.png",
      content_type: "image/png"
    )
    replacement_image = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("replacement image"),
      filename: "replacement.png",
      content_type: "image/png"
    )
    note = create(
      :social_context_note,
      relationship_profile: profile,
      body: "<p>Original approved context.</p>#{ActionText::Attachment.from_attachable(original_image).to_html}"
    )
    analyzer = double
    allow(analyzer).to receive(:analyze) do |input:, **|
      note.update!(
        body: "<p>Unapproved replacement context.</p>#{ActionText::Attachment.from_attachable(replacement_image).to_html}"
      )
      expect(input.text).to include("Original approved context.")
      expect(input.text).not_to include("Unapproved replacement context.")
      expect(input.image_blob_ids).to eq([ original_image.id ])
      { interpretation: "Late result", suggested_uses: %w[message] }
    end

    expect do
      described_class.call(actor: user, note:, expected_lock_version: note.lock_version, analyzer:)
    end.to raise_error(ActiveRecord::StaleObjectError)

    expect(note.reload.interpretation).to be_nil
  end

  it "rejects a stale rendered revision before sending content to the analyzer" do
    user = create(:user)
    note = create(:social_context_note, relationship_profile: create(:relationship_profile, user:))
    rendered_lock_version = note.lock_version
    note.update!(body: "Newer private context that was not approved for analysis.")
    analyzer = double
    expect(analyzer).not_to receive(:analyze)

    expect do
      described_class.call(actor: user, note:, expected_lock_version: rendered_lock_version, analyzer:)
    end.to raise_error(ActiveRecord::StaleObjectError)
  end
end
