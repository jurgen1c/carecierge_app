require "rails_helper"

RSpec.describe "Conversational review queue", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Review pending memories", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 8, 10)) { example.run } }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  def queue_memory
    profile.memory_records.create!(title: "Possible preference", body: "May prefer quiet places", source: "ai_inferred", confidence: "inferred")
  end

  it "rejects unsupported high-impact memory edits before creating an approval" do
    queue_memory
    execute("approvals.search")
    request = user.approval_requests.sole
    expect {
      execute("approvals.edit", { id: request.id, lock_version: request.lock_version,
        corrected_title: "Correction", corrected_body: "Corrected content" })
    }.to raise_error(Concierge::InvalidArguments)
    expect(turn.actions.where(name: "approvals.edit")).not_to exist
    expect(request.reload.status).to eq("pending")
  end

  %w[approvals.approve proposals.review].each do |operation|
    it "retires a read recap after its final extracted memory is reviewed through #{operation}" do
      proposal = create(:extracted_memory, relationship_profile: profile)
      execute("recaps.read", { id: proposal.conversation_recap_id })
      execute("approvals.search")
      request = user.approval_requests.sole
      arguments = if operation == "approvals.approve"
        { id: request.id, lock_version: request.lock_version }
      else
        { id: proposal.id, decision: "approve" }
      end
      result = execute(operation, arguments)
      action = turn.actions.find(result.fetch("action_id"))
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
      expect(proposal.reload).to be_approved
      expect(Concierge::History.sources_current?(turn.reload)).to be(true)
    end
  end

  [ false, true ].each do |inherited|
    it "retires #{inherited ? 'inherited' : 'current'} review references after correcting their memory" do
      memory = queue_memory
      execute("approvals.search")
      active_turn, active_token = turn, token
      if inherited
        turn.finish!(token:, response: "Review the inferred memory")
        Timecop.travel(1.minute.from_now)
        active_turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Correct that memory", locale: "en",
          context: Concierge::Context.capture(user:, conversation:))
        active_token = active_turn.claim!
        Concierge::History.capture!(turn: active_turn, token: active_token)
      end
      Concierge::Execute.call(turn: active_turn, token: active_token, name: "memories.update",
        arguments: { id: memory.id, body: "Prefers lively places" })
      expect(memory.reload.body).to eq("Prefers lively places")
      expect(Concierge::History.sources_current?(active_turn.reload)).to be(true)
    end
  end

  it "materializes eligible reviews and requires exact approval before allowing higher-impact use" do
    memory = queue_memory
    records = execute("approvals.search").fetch("records")
    request = user.approval_requests.find(records.sole.fetch("id"))
    expect(records.sole).to include("risk_level" => "high", "certainty" => "inferred", "body" => memory.body)
    result = execute("approvals.approve", { id: request.id, lock_version: request.lock_version })
    expect(result).to include("status" => "awaiting_approval")
    expect(memory.reload).not_to be_high_impact_automation_allowed
    action = turn.actions.find(result.fetch("action_id"))
    expect(action.result.fetch("preview")).to include("higher-impact")
    2.times { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }
    expect(memory.reload).to be_high_impact_automation_allowed
    expect(request.reload).to have_attributes(status: "approved")
    expect(request.approval_decisions.count).to eq(1)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "defers eligible reviews without approving their source, and respects the deferral" do
    memory = queue_memory
    execute("approvals.search")
    request = user.approval_requests.sole
    execute("approvals.defer", { id: request.id, lock_version: request.lock_version, deferred_until: "2026-09-10T09:00:00-06:00" })
    expect(request.reload.status).to eq("deferred")
    expect(memory.reload).not_to be_high_impact_automation_allowed
    expect(execute("approvals.search").fetch("records")).to be_empty
    expect(execute("approvals.search", { status: "deferred" }).fetch("records").sole).to include("id" => request.id)
  end

  it "refuses a reviewed source changed at the same timestamp before applying an approval" do
    memory = queue_memory
    execute("approvals.search")
    request = user.approval_requests.sole
    result = execute("approvals.approve", { id: request.id, lock_version: request.lock_version })
    memory.update!(body: "A corrected detail")
    action = turn.actions.find(result.fetch("action_id"))
    expect do
      Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    end.to raise_error(Concierge::RequestConflict)
    expect(memory.reload).not_to be_high_impact_automation_allowed
  end

  it "rejects a local approval when another source read by its turn has been revoked" do
    note = profile.relationship_notes.create!(body: "Sensitive context", private: false)
    commitment = profile.commitments.create!(title: "Related follow-up")
    execute("notes.read", { id: note.id })
    result = execute("commitments.destroy", { id: commitment.id })
    action = turn.actions.find(result.fetch("action_id"))
    note.update!(private: true)
    expect(Concierge::Decide.available?(user:, action:)).to be(false)
    expect { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }
      .to raise_error(Concierge::ContextUnavailable)
    expect(commitment.reload).to be_persisted
    expect(action.reload.state).to eq("awaiting_approval")
  end

  it "rejects foreign review IDs before exposing source content" do
    other = create(:user)
    other_profile = create(:relationship_profile, user: other)
    memory = other_profile.memory_records.create!(title: "Private", body: "Private", source: "ai_inferred", confidence: "inferred")
    ApprovalQueue::Synchronize.call(user: other)
    expect { execute("approvals.read", { id: other.approval_requests.sole.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(memory.reload).not_to be_high_impact_automation_allowed
  end

  it "saves a corrected extracted proposal and returns the reviewed body and canonical memory" do
    proposal = create(:extracted_memory, relationship_profile: profile)
    execute("approvals.search")
    request = user.approval_requests.sole
    result = execute("approvals.edit", { id: request.id, lock_version: request.lock_version,
      corrected_title: "Tea preference", corrected_body: "Prefers green tea in the morning" })
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(proposal.reload.canonical_memory_record.body).to eq("Prefers green tea in the morning")
    expect(action.reload.result.fetch("record")).to include("body" => "Prefers green tea in the morning")
    expect(action.result.fetch("records")).to include(include("record_type" => "MemoryRecord", "id" => proposal.canonical_memory_record_id))
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end
end
