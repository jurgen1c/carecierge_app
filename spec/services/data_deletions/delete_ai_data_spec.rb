require "rails_helper"

RSpec.describe DataDeletions::DeleteAiData do
  it "locks and resets extraction state before deleting proposals" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    recap = create(
      :conversation_recap,
      relationship_profile: profile,
      extraction_status: "processing",
      extraction_started_at: 1.minute.ago
    )
    create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    operation_order = []

    allow_any_instance_of(ConversationRecap).to receive(:update!).and_wrap_original do |method, *args|
      operation_order << :recap_reset
      method.call(*args)
    end
    allow_any_instance_of(ExtractedMemory).to receive(:destroy!).and_wrap_original do |method, *args|
      operation_order << :proposal_delete
      method.call(*args)
    end

    described_class.call(user:)

    expect(operation_order).to eq(%i[recap_reset proposal_delete])
    expect(recap.reload.extraction_status).to eq("not_requested")
  end

  it "clears social analysis, advances its fences, and rejects an in-flight result" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(
      :social_context_note,
      relationship_profile: profile,
      body: "User-authored bookstore context",
      allow_suggestions: true,
      interpretation: "A bookstore message may be timely.",
      interpretation_status: "approved",
      suggested_uses: %w[message],
      analyzed_at: Time.current
    )
    pending_note = create(:social_context_note, relationship_profile: profile, body: "Unanalyzed user context")
    note_version = note.lock_version
    pending_note_version = pending_note.lock_version
    generation_version = profile.message_draft_generation_version
    analyzer = instance_double(SocialContextNotes::OpenAiAnalyzer)
    allow(analyzer).to receive(:analyze) do
      described_class.call(user:)
      { interpretation: "A stale replacement", suggested_uses: %w[message] }
    end

    expect do
      SocialContextNotes::Analyze.call(
        actor: user,
        note:,
        expected_lock_version: note_version,
        analyzer:
      )
    end.to raise_error(ActiveRecord::StaleObjectError)

    expect(note.reload).to have_attributes(
      allow_suggestions: true,
      interpretation: nil,
      interpretation_status: "not_requested",
      suggested_uses: [],
      analyzed_at: nil
    )
    expect(note.body.to_plain_text).to include("User-authored bookstore context")
    expect(note.lock_version).to be > note_version
    expect(pending_note.reload.lock_version).to be > pending_note_version
    expect(profile.reload.message_draft_generation_version).to eq(generation_version + 1)
  end
end
