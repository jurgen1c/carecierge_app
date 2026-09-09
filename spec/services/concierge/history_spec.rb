require "rails_helper"

RSpec.describe "Concierge conversation context", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }

  it "uses execution order when timestamps tie, independently of random UUID ordering" do
    current = new_turn("Correct this detail")
    memory = create(:memory_record, relationship_profile: profile)
    reference = { "record_type" => "MemoryRecord", "id" => memory.id, "relationship_profile_id" => profile.id,
      "version" => Concierge::RecordVersion.for(memory) }
    Timecop.freeze do
      current.actions.create!(id: "ffffffff-ffff-4fff-8fff-ffffffffffff", fingerprint: "a" * 64, name: "memories.read", state: "succeeded",
        result: { "record" => reference.merge("version" => "obsolete") })
      current.actions.create!(id: "00000000-0000-4000-8000-000000000000", fingerprint: "b" * 64, name: "memories.update", state: "succeeded",
        result: { "record" => reference })
    end
    expect(Concierge::History.sources_current?(current)).to be(true)
  end

  def new_turn(content)
    conversation.turns.create!(content:, locale: "en", request_key: SecureRandom.uuid,
      context: Concierge::Context.capture(user:, conversation:))
  end

  it "keeps authorized follow-up context but removes stale generated answers" do
    previous = new_turn("What does Ana like?")
    memory = profile.memory_records.create!(title: "Tea", body: "Green tea")
    token = previous.claim!
    Concierge::Execute.call(turn: previous, token:, name: "memories.read", arguments: { id: memory.id })
    previous.finish!(token:, response: "Ana likes green tea.")
    current = new_turn("What about a gift?")

    history = Concierge::History.messages(turn: current).map { |message| message[:content] }.join("\n")
    expect(history).to include("Ana likes green tea.", memory.id, "MemoryRecord", profile.id)
    memory.update!(body: "Coffee")
    expect(Concierge::History.messages(turn: current).map { |message| message[:content] }.join("\n")).not_to include("Ana likes green tea.", memory.id)
  end

  it "drops personal conversation history after a switch to professional mode" do
    previous = new_turn("Personal details")
    token = previous.claim!
    previous.finish!(token:, response: "Private personal context")
    profile.update!(relationship_mode: "professional")
    current = new_turn("Prepare for our work meeting")

    expect(Concierge::History.messages(turn: current)).to be_empty
  end

  it "expires inherited memory answers at the owner's midnight while allowing an explicitly stale reread" do
    user.create_notification_preference!(time_zone: "America/Costa_Rica")
    Time.use_zone("UTC") do
      Timecop.freeze(Time.utc(2026, 9, 9, 2)) do
        memory = create(:memory_record, relationship_profile: profile, stale_after: Date.new(2026, 9, 8))
        previous = new_turn("Recall the temporary detail")
        token = previous.claim!
        Time.use_zone("America/Costa_Rica") do
          Concierge::Execute.call(turn: previous, token:, name: "memories.read", arguments: { id: memory.id })
        end
        previous.finish!(token:, response: "The temporary detail is current.")
        current = new_turn("Use that detail")
        expect(Concierge::History.messages(turn: current).pluck(:content).join).to include(previous.response)
        Timecop.travel(Time.utc(2026, 9, 9, 6)) do
          expect(Concierge::History.messages(turn: current).pluck(:content).join).not_to include(previous.response)
          token = current.claim!
          result = Concierge::Execute.call(turn: current, token:, name: "memories.read", arguments: { id: memory.id })
          expect(result.fetch("record")).to include("stale" => true)
          expect(Concierge::History.sources_current?(current)).to be(true)
        end
        expect(Time.zone.name).to eq("UTC")
      end
    end
  end

  it "carries the authorized checklist and date identifiers needed to correct a touch in a follow-up" do
    date = create(:important_date, relationship_profile: profile)
    previous = new_turn("Prepare a thoughtful detail")
    token = previous.claim!
    result = Concierge::Execute.call(turn: previous, token:, name: "touches.prepare", arguments: { important_date_id: date.id })
    previous.finish!(token:, response: "The checklist is ready.")
    history = Concierge::History.messages(turn: new_turn("Change the wording of that touch")).map { |message| message[:content] }.join
    expect(history).to include(result.fetch("checklist_id"), date.id, "PersonalTouchItem")
  end

  it "bounds the number and size of previous messages" do
    12.times do
      previous = new_turn("x" * 8_000)
      token = previous.claim!
      previous.finish!(token:, response: "y" * 8_000)
    end
    messages = Concierge::History.messages(turn: new_turn("Now"))

    expect(messages.sum { |message| message[:content].length }).to be <= 12_000
    expect(messages.length).to be <= 12
  end

  it "excludes unselected work records and preserves selected work provenance" do
    preference = profile.relationship_preferences.create!(key: "Work communication", value: "Email", confidence: "confirmed")
    profile.relationship_preferences.create!(key: "Personal", value: "Secret")
    profile.update!(relationship_mode: "professional", professional_context: { "relationship_preferences" => [ preference.id ] })
    current = new_turn("What communication style for work?")
    token = current.claim!
    result = Concierge::Execute.call(turn: current, token:, name: "preferences.search", arguments: {})
    expect(result.fetch("records").map { |record| record["id"] }).to eq([ preference.id ])
    profile.update!(professional_context: {})
    expect(Concierge::History.sources_current?(current)).to be(false)
  end

  it "rechecks a person's mode even when the conversation has no selected person" do
    conversation.update!(relationship_profile: nil)
    current = new_turn("What do I know about Ana?")
    memory = profile.memory_records.create!(title: "Personal", body: "Private detail")
    token = current.claim!
    Concierge::Execute.call(turn: current, token:, name: "memories.read", arguments: { id: memory.id, relationship_profile_id: profile.id })
    profile.update!(relationship_mode: "professional")
    expect { Concierge::Context.verify!(turn: current) }.to raise_error(Concierge::ContextUnavailable)
  end
end
