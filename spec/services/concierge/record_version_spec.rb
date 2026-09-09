require "rails_helper"

RSpec.describe "Concierge source and approval freshness", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 8, 10)) { example.run } }

  def new_turn(selections: {})
    conversation.turns.create!(content: "Review this detail", locale: "en", request_key: SecureRandom.uuid,
      context: Concierge::Context.capture(user:, conversation:, selections:))
  end

  it "keeps the same source fingerprint across the provider and request time zones" do
    memory = profile.memory_records.create!(title: "Drink", body: "Tea")
    turn = new_turn
    token = turn.claim!
    Time.use_zone("America/Costa_Rica") do
      Concierge::Execute.call(turn:, token:, name: "memories.read", arguments: { id: memory.id })
    end
    Time.use_zone("UTC") do
      expect(Concierge::History.sources_current?(turn.reload)).to be(true)
    end
  end

  it "accepts an unchanged exact approval made in another time zone" do
    memory = profile.memory_records.create!(title: "Drink", body: "Tea")
    turn = new_turn
    token = turn.claim!
    Time.use_zone("America/Costa_Rica") do
      Concierge::Execute.call(turn:, token:, name: "memories.destroy", arguments: { id: memory.id })
    end
    Time.use_zone("UTC") do
      action = turn.actions.sole
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end
    expect(profile.memory_records.reload).to be_empty
  end

  it "invalidates recalled facts when content changes without a timestamp change" do
    memory = profile.memory_records.create!(title: "Drink", body: "Tea")
    turn = new_turn
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "memories.read", arguments: { id: memory.id })
    original_timestamp = memory.updated_at
    memory.update!(body: "Coffee")
    expect(memory.updated_at).to eq(original_timestamp)
    expect(Concierge::History.sources_current?(turn)).to be(false)
  end

  it "invalidates selected private rich text when only its body changed" do
    note = profile.relationship_notes.create!(category: "context", private: true, body: "Private detail")
    turn = new_turn(selections: { "private_note_ids" => [ note.id ] })
    original_timestamp = note.updated_at
    note.update!(body: "Changed private detail")
    expect(note.updated_at).to eq(original_timestamp)
    expect { Concierge::Context.verify!(turn:) }.to raise_error(Concierge::ContextUnavailable)
  end

  it "invalidates a derived interaction when its displayed source body changes" do
    recap = create(:conversation_recap, relationship_profile: profile, body: "Starts Monday")
    Interaction.sync_from_source!(recap)
    turn = new_turn
    Concierge::Execute.call(turn:, token: turn.claim!, name: "interactions.read", arguments: { id: recap.interaction.id })
    recap.update!(body: "Starts Tuesday")
    expect(Concierge::History.sources_current?(turn)).to be(false)
  end

  it "rejects a destructive approval after a same-timestamp content edit" do
    memory = profile.memory_records.create!(title: "Drink", body: "Tea")
    turn = new_turn
    token = turn.claim!
    Concierge::Execute.call(turn:, token:, name: "memories.destroy", arguments: { id: memory.id })
    action = turn.actions.sole
    memory.update!(body: "Coffee")
    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end.to raise_error(Concierge::RequestConflict)
    expect(memory.reload.body).to eq("Coffee")
    expect(action.reload.state).to eq("awaiting_approval")
  end
end
