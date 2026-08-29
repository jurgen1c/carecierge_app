require "rails_helper"

RSpec.describe ApprovalQueue::RecordSourceDecision do
  it "locks the account before the relationship" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    locks = []
    allow(user).to receive(:with_lock) do |lock_clause, &block|
      expect(lock_clause).to eq("FOR NO KEY UPDATE")
      locks << :account
      block.call
    end
    allow(profile).to receive(:with_lock) { |&block| locks << :relationship; block.call }

    described_class.call(user:, subject: memory, decision: "approve")

    expect(locks.first(2)).to eq(%i[account relationship])
    expect(memory.reload).to be_high_impact_automation_allowed
  end

  it "keeps discovery and application inside the relationship lock" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
    )
    inside_profile_lock = false
    allow(profile).to receive(:with_lock) do |&block|
      inside_profile_lock = true
      block.call
    ensure
      inside_profile_lock = false
    end
    expect(ApprovalDecisions::Apply).to receive(:call) do
      expect(inside_profile_lock).to be(true)
      proposal
    end

    described_class.call(user:, subject: proposal, decision: "approve")
  end

  it "keeps repeated terminal extracted-memory decisions idempotent" do
    {
      "approve" => {},
      "reject" => {},
      "correct" => { corrected_title: "Enjoys jasmine tea", corrected_body: "Enjoys jasmine tea on quiet evenings." }
    }.each do |decision, corrections|
      user = create(:user)
      profile = create(:relationship_profile, user:)
      proposal = create(
        :extracted_memory,
        relationship_profile: profile,
        conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
      )
      described_class.call(user:, subject: proposal, decision:, **corrections)

      expect do
        described_class.call(user:, subject: proposal, decision:, **corrections)
      end.not_to change(ApprovalRequest, :count)
    end
  end

  it "rejects a stale correction retry when its normalized content differs" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
    )
    described_class.call(
      user:,
      subject: proposal,
      decision: "correct",
      corrected_title: "Enjoys jasmine tea",
      corrected_body: "Enjoys jasmine tea on quiet evenings."
    )

    expect do
      described_class.call(
        user:,
        subject: proposal,
        decision: "correct",
        corrected_title: "  Enjoys   jasmine tea  ",
        corrected_body: "  Enjoys jasmine tea on quiet evenings.  "
      )
    end.not_to raise_error

    expect do
      described_class.call(
        user:,
        subject: proposal,
        decision: "correct",
        corrected_title: "Enjoys oolong tea",
        corrected_body: "Enjoys jasmine tea on quiet evenings."
      )
    end.to raise_error(described_class::DecisionConflict)

    expect do
      described_class.call(
        user:,
        subject: proposal,
        decision: "correct",
        corrected_title: "Enjoys jasmine tea",
        corrected_body: "Enjoys jasmine tea with friends."
      )
    end.to raise_error(described_class::DecisionConflict)
  end
end
