require "rails_helper"

RSpec.describe MessageDrafts::Generate do
  it "creates the profile workspace, an immutable generated revision, and privacy-minimized audit evidence" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    generator = double(generate: "Happy birthday, Maya!")

    revision = described_class.call(
      actor: user,
      relationship_profile: profile,
      draft_type: "birthday",
      tone: "warm",
      generator:
    )

    expect(revision).to have_attributes(position: 1, origin: "generated", content: "Happy birthday, Maya!")
    expect(revision.message_draft).to have_attributes(
      user:,
      relationship_profile_id: profile.id,
      draft_type: "birthday",
      tone: "warm"
    )
    expect(AuditEvent.where(user:, action: "message.drafted", target: profile)).to exist
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

  it "records sensitive-context access even when generation fails" do
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
        include_private_notes: true,
        generator:
      )
    end.to raise_error(MessageDrafts::GenerationError)

    expect(AuditEvent.where(user:, action: "sensitive_record.accessed", target: profile)).to exist
    expect(MessageDraft.where(relationship_profile: profile)).not_to exist
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

  it "does not persist when the profile is archived while the provider request is in flight" do
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

    expect(profile.reload.message_draft).to be_nil
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
