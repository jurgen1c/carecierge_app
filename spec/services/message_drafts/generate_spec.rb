require "rails_helper"

RSpec.describe MessageDrafts::Generate do
  it "creates the profile workspace, an immutable generated revision, and privacy-minimized audit evidence" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    generator = double
    expect(generator).to receive(:generate).with(
      draft_type: "birthday",
      tone: "warm",
      situation: "Maya shared a birthday post.",
      response_length: "short",
      formality: "casual",
      context: a_string_including("Maya"),
      locale: :en
    ).and_return("Happy birthday, Maya!")

    revision = described_class.call(
      actor: user,
      relationship_profile: profile,
      draft_type: "birthday",
      tone: "warm",
      situation: "Maya shared a birthday post.",
      response_length: "short",
      formality: "casual",
      generator:
    )

    expect(revision).to have_attributes(position: 1, origin: "generated", content: "Happy birthday, Maya!")
    expect(revision.message_draft).to have_attributes(
      user:,
      relationship_profile_id: profile.id,
      draft_type: "birthday",
      tone: "warm",
      situation: "Maya shared a birthday post.",
      response_length: "short",
      formality: "casual"
    )
    expect(AuditEvent.where(user:, action: "message.drafted", target: profile)).to exist
  end

  it "normalizes the untrusted situation before validating and sending it to the provider" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    generator = double
    expect(generator).to receive(:generate).with(hash_including(situation: "A short message")).and_return("A reply")

    revision = described_class.call(
      actor: user,
      relationship_profile: profile,
      draft_type: "check_in",
      tone: "warm",
      situation: " #{" " * MessageDraft::MAX_SITUATION_LENGTH}A short message ",
      generator:
    )

    expect(revision.message_draft.situation).to eq("A short message")
  end

  it "normalizes a rolling-deploy legacy tone into the independent provider axes" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    generator = double
    expect(generator).to receive(:generate).with(
      hash_including(tone: "warm", formality: "formal")
    ).and_return("A formal reply")

    revision = described_class.call(
      actor: user,
      relationship_profile: profile,
      draft_type: "check_in",
      tone: "formal",
      formality: "balanced",
      generator:
    )

    expect(revision.message_draft).to have_attributes(tone: "warm", formality: "formal")
  end

  it "reuses the profile workspace and appends a revision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    create(:draft_revision, message_draft: draft, position: 1)

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "concise",
        generator: double(generate: "Checking in—how are you doing?")
      )
    end.to change(draft.draft_revisions, :count).by(1).and change(MessageDraft, :count).by(0)

    expect(draft.reload).to have_attributes(draft_type: "check_in", tone: "concise")
    expect(draft.current_revision.position).to eq(2)
  end

  it "lets the latest overlapping request own both settings and the current revision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    latest_revision = nil
    first_generator = double
    allow(first_generator).to receive(:generate) do
      latest_revision = described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "boundary_setting",
        tone: "concise",
        situation: "Please stop calling during work.",
        response_length: "short",
        formality: "formal",
        generator: double(generate: "Please avoid calling me during work hours.")
      )
      "A stale response"
    end

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        situation: "How was your week?",
        response_length: "long",
        formality: "casual",
        generator: first_generator
      )
    end.to raise_error(MessageDrafts::GenerationSupersededError)

    draft = profile.reload.message_draft
    expect(draft).to have_attributes(
      draft_type: "boundary_setting",
      tone: "concise",
      situation: "Please stop calling during work.",
      response_length: "short",
      formality: "formal"
    )
    expect(draft.current_revision).to eq(latest_revision)
    expect(draft.draft_revisions.count).to eq(1)
  end

  it "does not let a late provider response supersede a newer manual edit" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    edited_revision = nil
    generator = double
    allow(generator).to receive(:generate) do
      edited_revision = profile.reload.message_draft.save_edit!(
        content: "I can talk tomorrow instead.",
        draft_type: "boundary_setting",
        tone: "concise",
        situation: "They asked if I can talk tonight.",
        response_length: "short",
        formality: "casual"
      )
      "A stale generated response"
    end

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        situation: "How was your week?",
        generator:
      )
    end.to raise_error(MessageDrafts::GenerationSupersededError)

    draft = profile.reload.message_draft
    expect(draft.current_revision).to eq(edited_revision)
    expect(draft.current_revision.content).to eq("I can talk tomorrow instead.")
    expect(draft.situation).to eq("They asked if I can talk tonight.")
  end

  it "does not let a late provider response supersede a newer restore" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    original = create(:draft_revision, message_draft: draft, position: 1, content: "Original response")
    create(:draft_revision, message_draft: draft, position: 2, content: "Current response")
    restored_revision = nil
    generator = double
    allow(generator).to receive(:generate) do
      restored_revision = draft.reload.restore_revision!(original)
      "A stale generated response"
    end

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        generator:
      )
    end.to raise_error(MessageDrafts::GenerationSupersededError)

    expect(draft.reload.current_revision).to eq(restored_revision)
    expect(draft.current_revision.content).to eq("Original response")
    expect(draft.draft_revisions.count).to eq(3)
  end

  it "preserves validated private workspace settings and records sensitive access when generation fails" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:relationship_note, relationship_profile: profile, private: true, body: "Sensitive note")
    generator = double
    allow(generator).to receive(:generate).and_raise(MessageDrafts::GenerationError, "Message drafting request failed")

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        situation: "They asked whether I am available this weekend.",
        response_length: "short",
        formality: "casual",
        include_private_notes: true,
        generator:
      )
    end.to raise_error(MessageDrafts::GenerationError)

    expect(AuditEvent.where(user:, action: "sensitive_record.accessed", target: profile)).to exist
    expect(profile.reload.message_draft).to have_attributes(
      situation: "They asked whether I am available this weekend.",
      response_length: "short",
      formality: "casual"
    )
    expect(profile.message_draft.draft_revisions).to be_empty
  end

  it "rejects vault context unless the caller supplies the active password-backed lease" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:privacy_vault_item, relationship_profile: profile)
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "boundary_setting",
        tone: "concise",
        include_vault_context: true,
        generator:
      )
    end.to raise_error(MessageDrafts::VaultAccessError, "Privacy vault access is required")
  end

  it "rejects a vault lease revoked after the controller initially checked it" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    lease = PrivacyVault::Lease.issue_for(user)
    user.increment!(:privacy_vault_lease_version)
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "boundary_setting",
        tone: "concise",
        include_vault_context: true,
        vault_lease: lease,
        generator:
      )
    end.to raise_error(MessageDrafts::VaultAccessError, "Privacy vault access is required")
  end

  it "rejects a vault lease when the password changes before locked context assembly" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    lease = PrivacyVault::Lease.issue_for(user)
    user.update!(password: "new-password123", password_confirmation: "new-password123")
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "boundary_setting",
        tone: "concise",
        include_vault_context: true,
        vault_lease: lease,
        generator:
      )
    end.to raise_error(MessageDrafts::VaultAccessError, "Privacy vault access is required")
  end

  it "rejects a vault lease that expires while generation waits to assemble context" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    issued_at = Time.zone.local(2026, 8, 11, 12)
    lease = Timecop.freeze(issued_at) { PrivacyVault::Lease.issue_for(user) }
    generator = double

    expect(generator).not_to receive(:generate)
    Timecop.freeze(issued_at + 10.minutes + 1.second) do
      expect do
        described_class.call(
          actor: user,
          relationship_profile: profile,
          draft_type: "boundary_setting",
          tone: "concise",
          include_vault_context: true,
          vault_lease: lease,
          generator:
        )
      end.to raise_error(MessageDrafts::VaultAccessError, "Privacy vault access is required")
    end
  end

  it "builds provider context while holding the profile lock used by vault protection" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    lock_depth = 0
    builder = instance_double(MessageDrafts::ContextBuilder)

    allow(profile).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      lock_depth += 1
      method.call(*args, &block)
    ensure
      lock_depth -= 1
    end
    allow(MessageDrafts::ContextBuilder).to receive(:new).and_return(builder)
    allow(builder).to receive(:call) do
      expect(lock_depth).to be_positive
      MessageDrafts::ContextBuilder::Result.new(text: "Preferred name: Maya", categories: [ "profile" ])
    end

    described_class.call(
      actor: user,
      relationship_profile: profile,
      draft_type: "check_in",
      tone: "warm",
      generator: double(generate: "Thinking of you.")
    )
  end

  it "fails closed for archived relationship profiles" do
    user = create(:user)
    profile = create(:relationship_profile, user:, discarded_at: Time.current)
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        generator:
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "does not append a revision when the profile is archived while the provider request is in flight" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    generator = double
    allow(generator).to receive(:generate) do
      RelationshipProfile.find(profile.id).update!(discarded_at: Time.current)
      "Thinking of you."
    end

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        generator:
      )
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(profile.reload.message_draft).to be_present
    expect(profile.message_draft.draft_revisions).to be_empty
  end

  it "does not recreate a draft deleted while the provider request is in flight" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    create(:draft_revision, message_draft: draft, position: 1, content: "Delete me")
    generator = double
    allow(generator).to receive(:generate) do
      draft.destroy!
      "A late provider response"
    end

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        draft_type: "check_in",
        tone: "warm",
        generator:
      )
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(profile.reload.message_draft).to be_nil
  end
end
