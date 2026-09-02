require "rails_helper"

RSpec.describe MemoryExtractions::Review do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:recap) { create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review") }

  it "approves a proposal once while preserving AI source and uncertainty" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile, confidence: "medium")

    expect { described_class.call(extracted_memory: proposal, reviewer: user, decision: "approve") }
      .to change(MemoryRecord, :count).by(1)

    proposal.reload
    expect(proposal).to have_attributes(status: "approved", reviewed_by: user)
    expect(proposal.canonical_memory_record).to have_attributes(
      title: proposal.title,
      body: proposal.body,
      source: "ai_inferred",
      confidence: "medium"
    )

    expect { described_class.call(extracted_memory: proposal, reviewer: user, decision: "approve") }
      .not_to change(MemoryRecord, :count)
  end

  it "locks the profile before the proposal so deletion and review share one order" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile)

    expect(profile).to receive(:with_lock).ordered.and_call_original
    expect(proposal).to receive(:lock!).ordered.and_call_original

    described_class.call(extracted_memory: proposal, reviewer: user, decision: "approve")
  end

  it "rejects a proposal without canonical mutation" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile)

    expect do
      described_class.call(extracted_memory: proposal, reviewer: user, decision: "reject")
    end.to change(AuditEvent, :count).by(1)
      .and change(MemoryRecord, :count).by(0)

    expect(proposal.reload).to have_attributes(status: "rejected", reviewed_by: user)
    expect(user.audit_events.last).to have_attributes(
      action: "approval.rejected",
      target_type: "RelationshipProfile",
      target_id: profile.id,
      metadata: { "result" => "reject" }
    )
  end

  it "closes an existing queue request when reviewed from the relationship profile" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile)
    approval_request = create(:approval_request, user:, subject: proposal)

    expect do
      described_class.call(extracted_memory: proposal, reviewer: user, decision: "reject")
    end.to change(ApprovalDecision, :count).by(1)
      .and change(AuditEvent, :count).by(1)

    expect(approval_request.reload).to have_attributes(status: "rejected", decided_at: be_within(1.second).of(Time.current))
    expect(approval_request.approval_decisions.sole).to have_attributes(decision: "reject", user:)
    expect(user.audit_events.last).to have_attributes(
      action: "approval.rejected",
      target: approval_request,
      metadata: { "request_kind" => "extracted_memory", "result" => "reject" }
    )
  end

  it "corrects a proposal while retaining the original and recording user-confirmed content" do
    proposal = create(
      :extracted_memory,
      conversation_recap: recap,
      relationship_profile: profile,
      title: "Likes jazz",
      body: "Jazz is always preferred."
    )

    described_class.call(
      extracted_memory: proposal,
      reviewer: user,
      decision: "correct",
      corrected_title: "Enjoys live jazz",
      corrected_body: "Enjoys live jazz for special evenings, but not every dinner."
    )

    proposal.reload
    expect(proposal).to have_attributes(
      status: "corrected",
      title: "Likes jazz",
      body: "Jazz is always preferred.",
      corrected_title: "Enjoys live jazz",
      corrected_body: "Enjoys live jazz for special evenings, but not every dinner."
    )
    expect(proposal.canonical_memory_record).to have_attributes(
      title: "Enjoys live jazz",
      source: "user_corrected",
      confidence: "confirmed"
    )
  end

  it "rejects a reviewer outside the profile ownership boundary" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile)

    expect {
      described_class.call(extracted_memory: proposal, reviewer: create(:user), decision: "approve")
    }.to raise_error(Pundit::NotAuthorizedError)

    expect(proposal.reload.status).to eq("pending")
    expect(proposal.canonical_memory_record).to be_nil
  end
end
