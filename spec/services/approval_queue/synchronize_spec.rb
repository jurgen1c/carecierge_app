require "rails_helper"

RSpec.describe ApprovalQueue::Synchronize do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  it "uses a no-key account lock so child decision evidence cannot deadlock" do
    expect(user).to receive(:with_lock).with("FOR NO KEY UPDATE").and_call_original

    described_class.call(user:)
  end

  it "queues pending extracted memories and blocked high-impact memories once" do
    recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, confidence: "low")
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "inferred")
    create(:memory_record, relationship_profile: profile, source: "user_confirmed", confidence: "confirmed")

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(2)
    expect { described_class.call(user:) }.not_to change(ApprovalRequest, :count)

    expect(user.approval_requests.find_by(subject: proposal)).to have_attributes(
      kind: "extracted_memory",
      action_key: "review_extracted_memory",
      risk_level: "medium",
      confidence: "low"
    )
    expect(user.approval_requests.find_by(subject: memory)).to have_attributes(
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "inferred"
    )
  end

  it "bounds source reconciliation work for each queue visit" do
    stub_const("ApprovalQueue::Synchronize::SOURCE_LIMIT", 2)
    3.times do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(2)
  end

  it "bounds reconciliation of existing open requests for each queue visit" do
    stub_const("ApprovalQueue::Synchronize::REQUEST_LIMIT", 2)
    memories = 3.times.map do
      create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    end
    described_class.call(user:)
    memories.each { |memory| memory.update!(source: "user_confirmed", confidence: "confirmed") }

    described_class.call(user:)

    expect(user.approval_requests.where(status: "superseded").count).to eq(2)
    expect(user.approval_requests.open.count).to eq(1)
  end

  it "does not let unchanged eligible requests starve later ineligible work" do
    stub_const("ApprovalQueue::Synchronize::REQUEST_LIMIT", 2)
    2.times do
      memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
      create(
        :approval_request,
        user:,
        subject: memory,
        kind: "memory_record",
        action_key: "approve_high_impact_memory",
        risk_level: "high",
        confidence: "low"
      )
    end
    stale_memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    stale_request = create(
      :approval_request,
      user:,
      subject: stale_memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )
    stale_memory.update!(source: "user_confirmed", confidence: "confirmed")

    2.times { described_class.call(user:) }

    expect(stale_request.reload.status).to eq("superseded")
  end

  it "never imports another owner's pending work" do
    foreign_profile = create(:relationship_profile)
    proposal = create(:extracted_memory, relationship_profile: foreign_profile, conversation_recap: create(:conversation_recap, relationship_profile: foreign_profile))

    described_class.call(user:)

    expect(ApprovalRequest.find_by(subject: proposal)).to be_nil
  end

  it "does not queue protected high-impact memory" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    PrivacyVault::Protect.call(actor: user, protectable: memory)

    described_class.call(user:)

    expect(user.approval_requests.find_by(subject: memory)).to be_nil
  end

  it "refreshes an open request after an eligible source edit and invalidates its old lock" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)
    original_lock_version = approval_request.lock_version

    memory.update!(body: "Updated source-backed detail", confidence: "inferred")
    described_class.call(user:)

    expect(approval_request.reload).to have_attributes(
      status: "pending",
      confidence: "inferred",
      subject_updated_at: memory.updated_at
    )
    expect(approval_request.lock_version).to be > original_lock_version
  end

  it "supersedes an open request when the source is no longer eligible" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)

    memory.update!(source: "user_confirmed", confidence: "confirmed")
    described_class.call(user:)

    expect(approval_request.reload).to have_attributes(status: "superseded", decided_at: be_present)
    expect(user.approval_requests.open.find_by(subject: memory)).to be_nil
  end

  it "supersedes open work when its relationship is archived" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)

    profile.archive!
    described_class.call(user:)

    expect(approval_request.reload.status).to eq("superseded")
    expect(user.approval_requests.open.find_by(subject: memory)).to be_nil
  end

  it "revalidates a stale source instance immediately before enqueueing" do
    recap = create(:conversation_recap, relationship_profile: profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    stale_proposal = ExtractedMemory.find(proposal.id)
    proposal.update_columns(status: "approved", reviewed_at: Time.current, updated_at: Time.current)
    synchronizer = described_class.new(user:)

    synchronizer.send(
      :enqueue,
      subject: stale_proposal,
      action_key: "review_extracted_memory"
    )

    expect(user.approval_requests.find_by(subject: proposal)).to be_nil
  end

  it "derives request metadata from the source after locking and reloading it" do
    recap = create(:conversation_recap, relationship_profile: profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, confidence: "high")
    stale_proposal = ExtractedMemory.find(proposal.id)
    proposal.update_columns(confidence: "low", updated_at: Time.current)
    synchronizer = described_class.new(user:)

    synchronizer.send(
      :enqueue,
      subject: stale_proposal,
      action_key: "review_extracted_memory"
    )

    expect(user.approval_requests.find_by!(subject: proposal)).to have_attributes(
      kind: "extracted_memory",
      risk_level: "medium",
      confidence: "low",
      subject_updated_at: proposal.reload.updated_at
    )
  end

  it "does not recreate a terminal request until the source meaningfully changes" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: memory)
    ApprovalDecisions::Apply.call(
      approval_request:,
      actor: user,
      decision: "reject",
      lock_version: approval_request.lock_version
    )

    expect { described_class.call(user:) }.not_to change(ApprovalRequest, :count)

    memory.update!(body: "Updated source-backed detail")

    expect { described_class.call(user:) }.to change(ApprovalRequest, :count).by(1)
    expect(user.approval_requests.open.find_by(subject: memory)).to be_present
  end

  it "keeps dismissed pending proposals out of the queue" do
    recap = create(:conversation_recap, relationship_profile: profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    described_class.call(user:)
    approval_request = user.approval_requests.find_by!(subject: proposal)
    ApprovalDecisions::Apply.call(
      approval_request:,
      actor: user,
      decision: "dismiss",
      lock_version: approval_request.lock_version
    )

    expect { described_class.call(user:) }.not_to change(ApprovalRequest, :count)
    expect(user.approval_requests.open.find_by(subject: proposal)).to be_nil
  end
end
