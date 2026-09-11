require "rails_helper"

RSpec.describe "Concierge data controls", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  def conversation_for(profile: nil, content: "Remember this", context: {})
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile, title: "Our conversation")
    turn = conversation.turns.create!(content:, locale: "en", request_key: SecureRandom.uuid,
      context: Concierge::Context.capture(user:, conversation:).merge(context))
    [ conversation, turn ]
  end

  it "excludes another person's inherited response from a relationship-only export" do
    other = create(:relationship_profile, user:, first_name: "Bob", preferred_name: nil)
    conversation, first = conversation_for(profile:)
    token = first.claim!
    Concierge::Execute.call(turn: first, token:, name: "people.search", arguments: { query: "Bob" })
    first.finish!(token:, response: "Bob has a new job")
    Timecop.travel(1.minute.from_now) do
      later = conversation.turns.create!(content: "Tell me more", locale: "en", request_key: SecureRandom.uuid,
        context: Concierge::Context.capture(user:, conversation:))
      later_token = later.claim!
      Concierge::History.capture!(turn: later, token: later_token)
      later.finish!(token: later_token, response: "Bob has a new job")
      expect(later.referenced_profile_ids).to include(profile.id, other.id)
      exported = DataExports::ConciergeConversations.new(user:, relationship_profile: profile).to_a
      expect(exported.to_json).not_to include("Bob has a new job")
    end
  end

  it "exports owned messages and outcomes without execution tokens or vault leases" do
    conversation, turn = conversation_for(profile:)
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: { title: "Tea", body: "Green tea" })
    turn.finish!(token:, response: "Saved the tea preference")
    other = ConciergeConversation.create!(user: create(:user), title: "Foreign conversation")
    snapshot = DataExports::Snapshot.new(user:).to_h
    entries = snapshot.fetch("concierge_conversations")
    expect(entries.map { |entry| entry["id"] }).to eq([ conversation.id ])
    expect(entries.to_json).to include("Remember this", "Saved the tea preference", "Green tea")
    expect(entries.to_json).not_to include(token, "run_token", "request_key", "fingerprint", "vault_lease", other.id)
  end

  it "redacts protected conversational text from ordinary exports" do
    _conversation, turn = conversation_for(content: "Protected discussion", context: {
      "vault_item_ids" => [ SecureRandom.uuid ], "vault_lease" => { "secret" => "never export me" }
    })
    turn.finish!(token: turn.claim!, response: "Protected reply")
    exported = DataExports::Snapshot.new(user:).to_h.fetch("concierge_conversations")
    expect(exported.to_json).not_to include("Protected discussion", "Protected reply", "never export me")
    expect(exported.sole.fetch("turns").sole).to include("content_redacted" => true)
  end

  it "includes protected history only in a reauthenticated sensitive export without renewing its saved lease" do
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    lease = PrivacyVault::Lease.issue_for(user)
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Protected discussion", locale: "en",
      context: Concierge::Context.capture(user:, conversation:, selections: { "vault_item_ids" => [ item.id ] }, vault_lease: lease))
    turn.finish!(token: turn.claim!, response: "Protected reply")
    Timecop.travel(11.minutes.from_now) do
      exported = DataExports::Snapshot.new(user:, include_sensitive: true).to_h.fetch("concierge_conversations")
      expect(exported.to_json).to include("Protected discussion", "Protected reply")
      expect(exported.to_json).not_to include("vault_lease", "password_fingerprint", lease.password_fingerprint)
      expect(turn.reload.context["vault_lease"]).to eq(lease.to_session)
    end
  end

  it "exports a currently authorized generated vault result after reauthentication without renewing either saved lease" do
    conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    lease = PrivacyVault::Lease.issue_for(user)
    user.automation_permissions.create!(relationship_profile: profile, capability: "draft_messages", mode: "allow_automatically")
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Prepare a private draft", locale: "en",
      context: Concierge::Context.capture(user:, conversation:, selections: { "vault_item_ids" => [ item.id ] }, vault_lease: lease))
    allow_any_instance_of(MessageDrafts::OpenAiGenerator).to receive(:generate).and_return("The selected private draft")
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "drafts.generate", arguments: { draft_type: "check_in", tone: "warm" })
    turn.finish!(token:, response: "Prepared the private draft")
    Timecop.travel(11.minutes.from_now) do
      ordinary = DataExports::Snapshot.new(user:).to_h.fetch("concierge_conversations")
      expect(ordinary.sole.fetch("turns").sole).to include("content_redacted" => true)
      sensitive = DataExports::Snapshot.new(user:, include_sensitive: true).to_h.fetch("concierge_conversations")
      exported = sensitive.sole.fetch("turns").sole
      expect(exported).to include("response" => "Prepared the private draft")
      expect(exported.fetch("actions").sole.dig("result", "record", "body")).to eq("The selected private draft")
      expect(turn.reload.context["vault_lease"]).to eq(lease.to_session)
      expect(Concierge::History.sources_current?(turn)).to be(false)
      item.update!(suggestion_usage: "excluded")
      revoked = DataExports::Snapshot.new(user:, include_sensitive: true).to_h.fetch("concierge_conversations")
      expect(revoked.sole.fetch("turns").sole).to include("content_redacted" => true)
    end
  end

  it "cascades conversation messages and actions when the account is deleted" do
    _conversation, turn = conversation_for
    Concierge::Execute.call(turn:, token: turn.claim!, name: "people.search", arguments: {})
    user.destroy!
    expect(ConciergeTurn.exists?(turn.id)).to be(false)
    expect(ConciergeAction.where(turn_id: turn.id)).to be_empty
  end

  it "does not include another person's turns in a relationship-specific export" do
    conversation, turn = conversation_for(profile:, content: "About the selected person")
    other = create(:relationship_profile, user:)
    conversation.turns.create!(request_key: SecureRandom.uuid, content: "About another person", locale: "en",
      context: { relationship_profile_id: other.id, relationship_mode: "personal" })
    exported = DataExports::Snapshot.new(user:, relationship_profile: profile).to_h.fetch("concierge_conversations")
    expect(exported.sole.fetch("turns").map { |entry| entry["id"] }).to eq([ turn.id ])
    expect(exported.to_json).not_to include("About another person")
  end

  it "deletes conversational AI history without deleting explicitly saved memories, and fences delayed jobs" do
    conversation, turn = conversation_for(profile:)
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: { title: "Explicit memory", body: "Keep this" })
    DataDeletions::DeleteAiData.call(user:)
    expect(ConciergeConversation.exists?(conversation.id)).to be(false)
    expect(ConciergeTurn.exists?(turn.id)).to be(false)
    expect(ConciergeAction.where(turn_id: turn.id)).to be_empty
    expect(profile.memory_records.sole.body).to eq("Keep this")
    expect { ConciergeResponseJob.perform_now(turn.id) }.not_to change(ConciergeConversation, :count)
  end

  it "erases linked mixed-person history when a relationship is deleted, preserving unrelated history" do
    selected, = conversation_for(profile:)
    mixed, turn = conversation_for
    token = turn.claim!
    memory = profile.memory_records.create!(title: "Job", body: "New job")
    Concierge::Execute.call(turn:, token:, name: "memories.read", arguments: { id: memory.id, relationship_profile_id: profile.id })
    unrelated, = conversation_for(content: "Unrelated thought")

    profile.destroy!

    expect(ConciergeConversation.where(id: [ selected.id, mixed.id ])).to be_empty
    expect(unrelated.reload).to be_persisted
  end

  it "rolls back history deletion when deleting the relationship fails" do
    conversation, = conversation_for(profile:)
    allow(profile).to receive(:destroy_row).and_raise(ActiveRecord::StatementInvalid, "simulated failure")
    expect { profile.destroy! }.to raise_error(ActiveRecord::StatementInvalid)
    expect(conversation.reload).to be_persisted
    expect(profile.reload).to be_persisted
  end
end
