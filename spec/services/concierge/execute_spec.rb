require "rails_helper"

RSpec.describe "Executing relationship tools", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Ana") }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) do
    conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remember Ana likes quiet restaurants", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
  end
  let(:token) { turn.claim! }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  it "rejects impossible timestamp dates before saving a normalized reminder" do
    Timecop.freeze(Time.utc(2026, 1, 1)) do
      user.automation_permissions.create!(relationship_profile: profile, capability: "send_reminders", mode: "allow_automatically")
      expect do
        execute("reminders.create", { title: "Call", scheduled_at: "2026-02-30T09:00:00-06:00" })
      end.to raise_error(Concierge::InvalidArguments)
      expect(user.reminders).to be_empty
      result = execute("reminders.create", { title: "Leap day call", scheduled_at: "2028-02-29T09:00:00-06:00" })
      expect(result).to include("status" => "succeeded")
      expect(user.reminders.sole.scheduled_at).to eq(Time.iso8601("2028-02-29T09:00:00-06:00"))
    end
  end

  it "preserves revoked source dependencies instead of overwriting a repeated read result" do
    memory = create(:memory_record, relationship_profile: profile, title: "Sensitive fact", body: "Protected detail")
    first = execute("memories.search")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    expect { execute("memories.search") }.to raise_error(Concierge::ContextUnavailable)
    expect(turn.actions.find_by!(name: "memories.search").result).to eq(first)
    expect(Concierge::History.sources_current?(turn)).to be(false)
  end

  it "rejects malformed memory expiry without clearing a saved deadline" do
    memory = create(:memory_record, relationship_profile: profile, stale_after: Date.new(2026, 9, 30))
    expect do
      execute("memories.update", { id: memory.id, stale_after: "not-a-date" })
    end.to raise_error(Concierge::InvalidArguments)
    expect(memory.reload.stale_after).to eq(Date.new(2026, 9, 30))
  end

  it "saves a real explicitly requested memory and reuses its receipt on replay" do
    args = { "relationship_profile_id" => profile.id, "title" => "Restaurants", "body" => "Prefers quiet restaurants" }
    first = execute("memories.create", args)
    expect(first).to include("status" => "succeeded")
    memory = profile.memory_records.sole
    expect(memory).to have_attributes(body: args["body"], source: "user_confirmed")

    expect { expect(execute("memories.create", args)).to eq(first) }.not_to change(MemoryRecord, :count)
    expect(turn.actions.count).to eq(1)
  end

  it "rejects unrecognized attributes instead of assigning authority from tool arguments" do
    expect do
      execute("memories.create", { "relationship_profile_id" => profile.id, "title" => "Tea", "body" => "Green", "user_id" => user.id })
    end.to raise_error(Concierge::InvalidArguments)
    expect(profile.memory_records).to be_empty
  end

  it "rejects foreign relationships and stale workers" do
    other = create(:relationship_profile)
    expect { execute("memories.create", { "relationship_profile_id" => other.id, "title" => "Tea", "body" => "Green" }) }.to raise_error(ActiveRecord::RecordNotFound)

    token
    turn.fail!(token:)
    expect { execute("people.search", { "query" => "Ana" }) }.to raise_error(Concierge::ExecutionExpired)
  end

  it "requires a separate exact-action decision before removing a memory" do
    memory = profile.memory_records.create!(title: "Tea", body: "Black tea")
    result = execute("memories.destroy", { "relationship_profile_id" => profile.id, "id" => memory.id })
    expect(result).to include("status" => "awaiting_approval")
    expect(memory.reload).to be_persisted
    action = turn.actions.sole
    expect(action.result.fetch("preview")).to include("Tea", "Black tea")

    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end.to change(MemoryRecord, :count).by(-1)
    expect(action.reload.state).to eq("succeeded")
    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end.not_to change(MemoryRecord, :count)
  end

  it "rejects an approval if its target changed after the preview" do
    memory = profile.memory_records.create!(title: "Tea", body: "Black tea")
    execute("memories.destroy", { "relationship_profile_id" => profile.id, "id" => memory.id })
    action = turn.actions.sole
    memory.update!(body: "Corrected by the owner")

    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end.to raise_error(Concierge::RequestConflict)
    expect(memory.reload.body).to eq("Corrected by the owner")
  end

  it "limits approved decisions to the conversation owner and exact fingerprint" do
    memory = profile.memory_records.create!(title: "Tea", body: "Black tea")
    execute("memories.destroy", { "relationship_profile_id" => profile.id, "id" => memory.id })
    action = turn.actions.sole

    expect do
      Concierge::Decide.call(user: create(:user), action:, decision: "approve", fingerprint: action.fingerprint)
    end.to raise_error(Pundit::NotAuthorizedError)
    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: "altered")
    end.to raise_error(Concierge::RequestConflict)
  end

  it "returns only the owner's name matches so ambiguity can be clarified" do
    create(:relationship_profile, user:, first_name: "Ana", last_name: "Two")
    create(:relationship_profile, first_name: "Ana", last_name: "Private")

    results = execute("people.search", { "query" => "Ana" }).fetch("records")
    expect(results.size).to eq(2)
    expect(results.map { |record| record.fetch("title") }).not_to include("Ana Private")
  end

  it "retrieves unprotected current memories with provenance without elevating proposals" do
    profile.memory_records.create!(title: "Job", body: "Starting Monday", source: "user_confirmed")
    profile.memory_records.create!(title: "Speculation", body: "Starting Tuesday", status: "needs_review", source: "ai_inferred")

    records = execute("memories.search", { "relationship_profile_id" => profile.id, "query" => "Starting" }).fetch("records")
    expect(records.map { |record| record.fetch("title") }).to eq([ "Job" ])
    expect(records.sole).to include("source" => "user_confirmed", "certainty" => "confirmed")
  end

  it "does not replay stale sensitive content from an earlier successful mutation" do
    arguments = { title: "First title", body: "Initial content" }
    execute("memories.create", arguments)
    profile.memory_records.sole.update!(title: "Corrected", body: "New content")
    result = execute("memories.create", arguments)
    expect(result).to include("status" => "succeeded", "source_changed" => true)
    expect(result).not_to have_key("record")
    expect(profile.memory_records.count).to eq(1)
  end
end
