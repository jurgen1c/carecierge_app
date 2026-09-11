require "rails_helper"

RSpec.describe "Generated concierge actions", type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) do
    conversation.turns.create!(request_key: SecureRandom.uuid, content: "Draft a check-in", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
  end
  let(:token) { turn.claim! }
  let(:generator) { instance_double(MessageDrafts::OpenAiGenerator) }

  before do
    create(:automation_permission, user:, capability: "draft_messages", mode: "allow_automatically")
    allow(MessageDrafts::OpenAiGenerator).to receive(:new).and_return(generator)
  end

  def execute(name = "drafts.generate", arguments = { draft_type: "check_in", tone: "warm" })
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  it "persists one real revision with its receipt and skips the provider on replay" do
    expect(generator).to receive(:generate).once.and_return("How was your week?")
    result = execute
    expect(result).to include("status" => "succeeded")
    expect(result.fetch("record")).to include("record_type" => "DraftRevision", "body" => "How was your week?")
    expect { expect(execute).to eq(result) }.not_to change(DraftRevision, :count)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "keeps generated provenance stable across request time zones while respecting owner-local expiry" do
    Timecop.freeze(Time.utc(2026, 9, 9, 2)) do
      user.create_notification_preference!(time_zone: "America/Costa_Rica")
      create(:memory_record, relationship_profile: profile, stale_after: Date.new(2026, 9, 8))
      allow(generator).to receive(:generate).and_return("A thoughtful check-in")
      Time.use_zone("America/Costa_Rica") do
        expect(execute).to include("status" => "succeeded")
        expect(Concierge::History.sources_current?(turn)).to be(true)
      end
      Time.use_zone("UTC") do
        expect(Concierge::History.sources_current?(turn)).to be(true)
        expect(Time.zone.name).to eq("UTC")
      end
      Timecop.travel(6.hours.from_now) do
        expect(Concierge::History.sources_current?(turn)).to be(false)
      end
    end
  end

  it "releases application locks for provider work and atomically rolls output back when the conversation disappears" do
    baseline_transactions = ActiveRecord::Base.connection.open_transactions
    allow(generator).to receive(:generate) do
      expect(ActiveRecord::Base.connection.open_transactions).to eq(baseline_transactions)
      conversation.destroy!
      "This result arrived too late"
    end
    expect { execute }.not_to change(DraftRevision, :count)
    expect(ConciergeAction.count).to eq(0)
  end

  %w[drafts briefings].each do |kind|
    it "retires an inherited #{kind} result after correcting its input and permits regeneration" do
      preference = create(:relationship_preference, relationship_profile: profile, value: "Green tea")
      allow(generator).to receive(:generate).and_return("A thoughtful check-in")
      allow_any_instance_of(RelationshipBriefings::OpenAiGenerator).to receive(:generate).and_return([
        { "key" => "preferences", "items" => [ { "body" => "Ask about tea", "certainty" => "inferred", "source_ids" => [ "preference:#{preference.id}" ] } ] }
      ])
      arguments = kind == "drafts" ? { draft_type: "check_in", tone: "warm" } : { interaction_context: "Lunch" }
      original = execute("#{kind}.generate", arguments).fetch("record")
      turn.finish!(token:, response: "Your preparation is ready.")
      later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Correct tea to coffee and regenerate", locale: "en",
        context: Concierge::Context.capture(user:, conversation:))
      later_token = later.claim!
      Concierge::History.capture!(turn: later, token: later_token)
      correction = Concierge::Execute.call(turn: later, token: later_token, name: "preferences.update", arguments: { id: preference.id, value: "Coffee" })
      expect(correction.fetch("superseded", [])).to include(original.slice("record_type", "id"))
      expect(preference.reload.value).to eq("Coffee")
      expect(Concierge::History.sources_current?(later.reload)).to be(true)
      result = Concierge::Execute.call(turn: later, token: later_token, name: "#{kind}.generate", arguments:)
      expect(result).to include("status" => "succeeded")
      expect(Concierge::History.sources_current?(later.reload)).to be(true)
    end
  end

  it "queues an explicitly approved generation only once and rechecks permission in the worker" do
    user.automation_permissions.find_by!(capability: "draft_messages").update!(mode: "ask_every_time")
    expect(generator).not_to receive(:generate)
    expect(execute.fetch("status")).to eq("awaiting_approval")
    action = turn.actions.sole
    expect do
      2.times { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }
    end.to have_enqueued_job(ConciergeActionJob).with(action.id).exactly(:once)
    user.automation_permissions.find_by!(capability: "draft_messages").update!(mode: "disabled")
    ConciergeActionJob.perform_now(action.id)
    expect(action.reload).to have_attributes(state: "failed", error_code: "permission_denied")
    expect(DraftRevision.count).to eq(0)
  end

  context "with committed generation transactions" do
    self.use_transactional_tests = false

    after { user.destroy! }

    it "records failure immediately when permission revocation rolls back the persisted generation result" do
      allow(generator).to receive(:generate) do
        user.automation_permissions.find_by!(capability: "draft_messages").update!(mode: "disabled")
        "This draft must be discarded"
      end
      expect do
        expect(execute).to include("status" => "failed", "error_code" => "permission_denied")
      end.not_to change(DraftRevision, :count)
      expect(turn.actions.sole).to have_attributes(state: "failed", run_token: nil, error_code: "permission_denied")
      expect(AuditEvent.where(user:, action: "message.drafted")).not_to exist
    end
  end

  it "executes an approved generation after the conversational turn finishes and ignores job redelivery" do
    user.automation_permissions.find_by!(capability: "draft_messages").update!(mode: "ask_every_time")
    execute
    action = turn.actions.sole
    turn.finish!(token:, response: "Review the draft request.")
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(generator).to receive(:generate).once.and_return("A thoughtful check-in")
    2.times { ConciergeActionJob.perform_now(action.id) }
    expect(action.reload.state).to eq("succeeded")
    expect(DraftRevision.count).to eq(1)
  end

  it "retries a failed provider action without duplicating its ledger entry" do
    allow(generator).to receive(:generate).and_raise(MessageDrafts::GenerationError)
    expect(execute).to include("status" => "failed")
    action = turn.actions.sole
    allow(generator).to receive(:generate).and_return("A recovered draft")
    Concierge::Decide.call(user:, action:, decision: "retry", fingerprint: action.fingerprint)
    ConciergeActionJob.perform_now(action.id)
    expect(action.reload).to have_attributes(state: "succeeded", attempts: 2)
    expect(turn.actions.count).to eq(1)
    expect(DraftRevision.count).to eq(1)
  end

  it "does not persist a generated revision if source context changes during the provider call" do
    preference = create(:relationship_preference, relationship_profile: profile, value: "Original")
    allow(generator).to receive(:generate) do
      preference.update!(value: "Corrected")
      "An obsolete draft"
    end
    expect { expect(execute).to include("status" => "failed") }.not_to change(DraftRevision, :count)
  end

  it "sends only the private notes selected for this turn and records sensitive access" do
    selected = create(:relationship_note, relationship_profile: profile, private: true, body: "Selected detail")
    create(:relationship_note, relationship_profile: profile, private: true, body: "Unselected secret")
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ selected.id ] }))
    expect(generator).to receive(:generate) do |**arguments|
      expect(arguments.fetch(:context)).to include("Selected detail")
      expect(arguments.fetch(:context)).not_to include("Unselected secret")
      "A private draft"
    end
    execute
    expect(AuditEvent.where(user:, action: "sensitive_record.accessed")).to exist
  end

  it "generates, reads, saves and dismisses a source-backed briefing through the same records" do
    note = create(:timeline_entry, relationship_profile: profile, title: "Started a new job")
    allow_any_instance_of(RelationshipBriefings::OpenAiGenerator).to receive(:generate).and_return([
      { "key" => "recent_activity", "items" => [ { "body" => "Ask how the new job is going", "certainty" => "inferred", "source_ids" => [ "timeline:#{note.id}" ] } ] }
    ])
    result = execute("briefings.generate", { interaction_context: "Lunch tomorrow" })
    briefing = profile.relationship_briefings.sole
    expect(result.fetch("record")).to include("id" => briefing.id, "certainty" => "inferred")
    expect(execute("briefings.read", { id: briefing.id }).fetch("record").fetch("body")).to include("new job")
    execute("briefings.save", { id: briefing.id })
    expect(briefing.reload).to be_saved
    execute("briefings.dismiss", { id: briefing.id })
    expect(briefing.reload).to be_dismissed
  end

  it "hides a briefing and gift idea when a cited public note becomes private" do
    note = profile.relationship_notes.create!(body: "Enjoys quiet gardens", private: false)
    source = { "id" => "public_note:#{note.id}", "label" => "Note", "sensitive" => false }
    briefing = create(:relationship_briefing, user:, relationship_profile: profile, context_categories: [ "public_notes" ],
      sections: [ { "key" => "recent_activity", "items" => [ { "body" => "Discuss quiet gardens", "certainty" => "inferred", "sources" => [ source ] } ] } ])
    idea = create(:gift_recommendation, user:, relationship_profile: profile, source_context: [ source.merge("certainty" => "confirmed") ])
    expect(Concierge::GeneratedSources.visible?(briefing, turn:)).to be(true)
    expect(Concierge::GeneratedSources.visible?(idea, turn:)).to be(true)
    note.update!(private: true)
    expect(Concierge::GeneratedSources.visible?(briefing.reload, turn: turn.reload)).to be(false)
    expect(Concierge::GeneratedSources.visible?(idea.reload, turn: turn.reload)).to be(false)
    expect { execute("briefings.read", { id: briefing.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    selected = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Use this private note", locale: "en",
      context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    expect(Concierge::GeneratedSources.visible?(briefing, turn: selected)).to be(true)
    PrivacyVault::Protect.call(actor: user, protectable: note)
    expect(Concierge::GeneratedSources.visible?(briefing, turn: selected.reload)).to be(false)
    expect(Concierge::GeneratedSources.visible?(idea, turn: selected.reload)).to be(false)
  end

  %w[correct delete].each do |change|
    it "hides a briefing after an input timeline fact changes via #{change}" do
      entry = create(:timeline_entry, relationship_profile: profile, title: "Started a new job")
      allow_any_instance_of(RelationshipBriefings::OpenAiGenerator).to receive(:generate).and_return([
        { "key" => "recent_activity", "items" => [ { "body" => "Ask about the new job", "certainty" => "inferred", "source_ids" => [ "timeline:#{entry.id}" ] } ] }
      ])
      result = execute("briefings.generate", { interaction_context: "Lunch" })
      expect(result.fetch("status")).to eq("succeeded")
      change == "correct" ? entry.update!(title: "Still searching for work") : entry.destroy!
      later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read briefing", locale: "en",
        context: Concierge::Context.capture(user:, conversation:))
      expect(Concierge::GeneratedSources.visible?(profile.relationship_briefings.sole, turn: later)).to be(false)
    end
  end

  it "revalidates uncited private-capable inputs used to generate a briefing" do
    note = profile.relationship_notes.create!(body: "Enjoys quiet gardens", private: false)
    timeline = create(:timeline_entry, relationship_profile: profile, title: "Started a new job")
    allow_any_instance_of(RelationshipBriefings::OpenAiGenerator).to receive(:generate).and_return([
      { "key" => "recent_activity", "items" => [ { "body" => "Discuss the job in a quiet garden", "certainty" => "inferred", "source_ids" => [ "timeline:#{timeline.id}" ] } ] }
    ])
    result = execute("briefings.generate", { interaction_context: "Lunch" })
    briefing = profile.relationship_briefings.find(result.dig("record", "id"))
    expect(Concierge::GeneratedSources.visible?(briefing, turn:)).to be(true)
    note.update!(private: true)
    expect(Concierge::GeneratedSources.visible?(briefing, turn: turn.reload)).to be(false)
    conversation.destroy!
    fresh_conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    fresh_turn = fresh_conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read briefing", locale: "en",
      context: Concierge::Context.capture(user:, conversation: fresh_conversation))
    expect(Concierge::GeneratedSources.visible?(briefing.reload, turn: fresh_turn)).to be(false)
  end

  it "rejects draft deletion approved before a new same-settings revision was saved" do
    allow(generator).to receive(:generate).and_return("Original wording")
    execute
    draft = profile.reload.message_draft
    result = execute("drafts.destroy", {})
    action = turn.actions.find(result.fetch("action_id"))
    fresh = draft.save_edit!(content: "Fresh wording", draft_type: draft.draft_type, tone: draft.tone,
      expected_relationship_mode: profile.relationship_mode)
    expect(Concierge::Decide.available?(user:, action:)).to be(false)
    expect { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }
      .to raise_error(Concierge::RequestConflict)
    expect(fresh.reload.content).to eq("Fresh wording")
  end

  it "retires read revisions when the draft workspace is deleted" do
    allow(generator).to receive(:generate).and_return("Hello there")
    execute
    execute("drafts.read", {})
    result = execute("drafts.destroy", {})
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(profile.reload.message_draft).to be_nil
    expect(Concierge::History.sources_current?(turn.reload)).to be(true)
  end

  it "does not reuse a draft after its public-note input becomes private" do
    note = profile.relationship_notes.create!(body: "Enjoys quiet gardens", private: false)
    allow(generator).to receive(:generate).and_return("Would you like to visit a quiet garden?")
    result = execute
    revision = profile.reload.message_draft.current_revision
    expect(Concierge::GeneratedSources.visible?(revision, turn:)).to be(true)
    note.update!(private: true)
    expect(Concierge::GeneratedSources.visible?(revision, turn: turn.reload)).to be(false)
    expect(Concierge::History.source_current?(result.fetch("record"), user:, turn:)).to be(false)
  end

  it "does not carry authored private-note authority into a later draft read" do
    execute("notes.create", { body: "A private garden plan", private: true })
    allow(generator).to receive(:generate).and_return("About the private garden plan")
    execute("drafts.generate", { draft_type: "check_in", tone: "warm", situation: "A private garden plan" })
    revision = profile.reload.message_draft.current_revision
    expect(Concierge::GeneratedSources.visible?(revision, turn:)).to be(true)
    later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read the draft", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    expect(Concierge::GeneratedSources.visible?(revision, turn: later)).to be(false)
  end

  it "requires regeneration for legacy generated drafts without verifiable input provenance" do
    draft = create(:message_draft, user:, relationship_profile: profile)
    revision = create(:draft_revision, message_draft: draft, context_categories: [ "public_notes" ])
    expect(Concierge::GeneratedSources.visible?(revision, turn:)).to be(false)
  end

  it "retires an inherited briefing when a tool-free-history follow-up regenerates it" do
    note = create(:timeline_entry, relationship_profile: profile, title: "Started a new job")
    allow_any_instance_of(RelationshipBriefings::OpenAiGenerator).to receive(:generate).and_return([
      { "key" => "recent_activity", "items" => [ { "body" => "Ask about the job", "certainty" => "inferred", "source_ids" => [ "timeline:#{note.id}" ] } ] }
    ])
    result = execute("briefings.generate", { interaction_context: "Lunch" })
    old_id = result.dig("record", "id")
    turn.finish!(token:, response: "The briefing is ready.")
    later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Prepare another briefing", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    later_token = later.claim!
    Concierge::History.capture!(turn: later, token: later_token)
    expect(later.actions).to be_empty
    result = Concierge::Execute.call(turn: later, token: later_token, name: "briefings.generate", arguments: { interaction_context: "Dinner" })
    expect(result).to include("status" => "succeeded")
    expect(result.fetch("superseded")).to include("record_type" => "RelationshipBriefing", "id" => old_id)
    expect(profile.relationship_briefings.find(old_id)).to be_dismissed
    expect(Concierge::History.sources_current?(later.reload)).to be(true)
  end

  it "reads only the selected allowed vault item and discards output after lease revocation" do
    selected = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed",
      payload: { "title" => "Selected", "body" => "Selected protected detail" })
    create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed",
      payload: { "title" => "Unselected", "body" => "Unselected protected secret" })
    turn.update!(context: Concierge::Context.capture(user:, conversation:,
      selections: { "vault_item_ids" => [ selected.id ] }, vault_lease: PrivacyVault::Lease.issue_for(user)))
    expect(generator).to receive(:generate) do |**arguments|
      expect(arguments.fetch(:context)).to include("Selected protected detail")
      expect(arguments.fetch(:context)).not_to include("Unselected protected secret")
      user.increment!(:privacy_vault_lease_version)
      "An expired protected draft"
    end
    expect { execute }.not_to change(DraftRevision, :count)
    expect(turn.actions.sole.state).to eq("failed")
    expect(VaultAccessEvent.where(user:, relationship_profile: profile, event_type: "viewed")).to exist
  end

  it "hides sensitive drafts generated from another selection or the manual category-wide workspace" do
    note = create(:relationship_note, relationship_profile: profile, private: true, body: "Selected")
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    allow(generator).to receive(:generate).and_return("A sensitive draft")
    result = execute
    expect(Concierge::History.source_current?(result.fetch("record"), user:, turn:)).to be(true)
    next_turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Show drafts", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    result = Concierge::Execute.call(turn: next_turn, token: next_turn.claim!, name: "drafts.read", arguments: {})
    expect(result.fetch("records")).to be_empty
    create(:draft_revision, message_draft: profile.reload.message_draft, position: 2, context_categories: [ "private_notes" ], content: "Manual private generation")
    expect(execute("drafts.read", {}).fetch("records").map { |record| record["body"] }).to eq([ "A sensitive draft" ])
  end

  it "keeps corrected and restored drafts as real immutable revisions" do
    allow(generator).to receive(:generate).and_return("First wording")
    first = execute.fetch("record")
    execute("drafts.update", { content: "Corrected wording" })
    expect(profile.reload.message_draft.current_revision.content).to eq("Corrected wording")
    execute("drafts.restore", { revision_id: first.fetch("id") })
    expect(profile.reload.message_draft.current_revision).to have_attributes(content: "First wording", origin: "restored")
    expect(profile.message_draft.draft_revisions.count).to eq(3)
  end

  it "fences a slow old provider when an explicitly retried action finishes first" do
    calls = 0
    allow(generator).to receive(:generate) do
      calls += 1
      if calls == 1
        action = turn.actions.sole
        Timecop.travel(6.minutes.from_now) do
          Concierge::Decide.call(user:, action:, decision: "retry", fingerprint: action.fingerprint)
          ConciergeActionJob.perform_now(action.id)
        end
        "Old provider output"
      else
        "Latest provider output"
      end
    end
    execute
    expect(profile.reload.message_draft.draft_revisions.pluck(:content)).to eq([ "Latest provider output" ])
    expect(turn.actions.sole).to have_attributes(state: "succeeded", attempts: 2)
  end

  it "recovers an approved job that never started without bypassing its original approval" do
    user.automation_permissions.find_by!(capability: "draft_messages").update!(mode: "ask_every_time")
    execute
    action = turn.actions.sole
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    Timecop.travel(6.minutes.from_now) do
      expect do
        Concierge::Decide.call(user:, action:, decision: "retry", fingerprint: action.fingerprint)
      end.to have_enqueued_job(ConciergeActionJob).with(action.id)
      expect(generator).to receive(:generate).once.and_return("Recovered approved draft")
      ConciergeActionJob.perform_now(action.id)
      expect(action.reload.state).to eq("succeeded")
    end
  end

  it "can replace a briefing already read in this turn while retiring the old source reference" do
    old = create(:relationship_briefing, user:, relationship_profile: profile, sections: [], context_categories: [])
    execute("briefings.read", { id: old.id })
    allow_any_instance_of(RelationshipBriefings::OpenAiGenerator).to receive(:generate).and_return([])
    result = execute("briefings.generate", { interaction_context: "Next conversation" })
    expect(result).to include("status" => "succeeded")
    expect(old.reload).to be_dismissed
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "does not import a professional draft after its approved work context changes" do
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Previous context" })
    allow(generator).to receive(:generate).and_return("Text from previous work context")
    first = execute
    expect(Concierge::History.source_current?(first.fetch("record"), user:, turn:)).to be(true)
    profile.update!(professional_context: { "organization" => "Current context" })
    current = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Show my draft", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    result = Concierge::Execute.call(turn: current, token: current.claim!, name: "drafts.read", arguments: {})
    expect(result.fetch("records")).to be_empty
  end

  it "keeps the original generation consent immutable when a turn's work selections advance" do
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Previous context" })
    allow(generator).to receive(:generate).and_return("Text from previous work context")
    first = execute
    profile.update!(professional_context: { "organization" => "Current context" })
    Concierge::Context.observe!(turn:, profile:)
    expect(Concierge::Context.verify!(turn:)).to be(true)
    expect(Concierge::History.source_current?(first.fetch("record"), user:, turn:)).to be(false)
  end

  it "does not reuse work drafts after the content of a selected source changes" do
    note = profile.relationship_notes.create!(category: "Work", body: "Previous agenda", private: false)
    profile.update!(relationship_mode: "professional", professional_context: { "relationship_notes" => [ note.id ] })
    allow(generator).to receive(:generate).and_return("Text from previous agenda")
    first = execute
    note.update!(body: "Current agenda")
    expect(Concierge::History.source_current?(first.fetch("record"), user:, turn:)).to be(false)
  end

  it "finds the exact generated origin without decrypting unrelated damaged history" do
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Studio" })
    unrelated = ConciergeConversation.create!(user:, relationship_profile: profile)
    earlier = unrelated.turns.create!(request_key: SecureRandom.uuid, content: "Unrelated request", locale: "en",
      context: Concierge::Context.capture(user:, conversation: unrelated))
    broken = earlier.actions.create!(name: "drafts.generate", fingerprint: "f" * 64, state: "succeeded", result: {})
    sql = ActiveRecord::Base.sanitize_sql_array([ "UPDATE concierge_actions SET result = ? WHERE id = ?", "damaged-ciphertext", broken.id ])
    ActiveRecord::Base.connection.execute(sql)
    allow(generator).to receive(:generate).and_return("A current work draft")
    result = execute
    expect(result).to include("status" => "succeeded")
    expect(Concierge::History.source_current?(result.fetch("record"), user:, turn:)).to be(true)
  end
end
