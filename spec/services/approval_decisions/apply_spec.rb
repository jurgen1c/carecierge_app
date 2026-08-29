require "rails_helper"

RSpec.describe ApprovalDecisions::Apply do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:recap) { create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review") }
  let(:proposal) { create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, confidence: "medium") }
  let(:approval_request) { create(:approval_request, user:, subject: proposal, confidence: proposal.confidence) }

  it "approves the underlying proposal and records immutable, privacy-minimized history" do
    expect do
      described_class.call(approval_request:, actor: user, decision: "approve", lock_version: approval_request.lock_version)
    end.to change(MemoryRecord, :count).by(1)
      .and change(ApprovalDecision, :count).by(1)
      .and change(AuditEvent, :count).by(1)

    expect(approval_request.reload).to have_attributes(status: "approved", decided_at: be_within(1.second).of(Time.current))
    expect(proposal.reload.status).to eq("approved")
    expect(approval_request.approval_decisions.sole).to have_attributes(decision: "approve", user:)
    expect(user.audit_events.last).to have_attributes(
      action: "approval.granted",
      target: approval_request,
      metadata: { "request_kind" => "extracted_memory", "result" => "approve" }
    )
    expect(user.audit_events.last.to_json).not_to include(proposal.title, proposal.body, proposal.source_excerpt)
  end

  it "edits a proposal before approving it" do
    described_class.call(
      approval_request:,
      actor: user,
      decision: "edit",
      lock_version: approval_request.lock_version,
      corrected_title: "Enjoys live jazz",
      corrected_body: "Enjoys live jazz for special evenings."
    )

    expect(approval_request.reload.status).to eq("approved")
    expect(proposal.reload).to have_attributes(status: "corrected", corrected_title: "Enjoys live jazz")
    expect(proposal.canonical_memory_record).to have_attributes(source: "user_corrected", confidence: "confirmed")
  end

  it "rejects the underlying proposal" do
    described_class.call(approval_request:, actor: user, decision: "reject", lock_version: approval_request.lock_version)

    expect(approval_request.reload.status).to eq("rejected")
    expect(proposal.reload.status).to eq("rejected")
  end

  it "requires a future time when deferring and leaves the source unchanged" do
    expect do
      described_class.call(approval_request:, actor: user, decision: "defer", lock_version: approval_request.lock_version)
    end.to raise_error(ActiveRecord::RecordInvalid)

    deferred_until = 2.days.from_now.change(hour: 9)
    described_class.call(
      approval_request:,
      actor: user,
      decision: "defer",
      lock_version: approval_request.lock_version,
      deferred_until:
    )

    expect(approval_request.reload).to have_attributes(status: "deferred", deferred_until:)
    expect(proposal.reload.status).to eq("pending")
  end

  it "interprets a zone-less deferral time in the owner's notification time zone" do
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")

    Timecop.freeze(Time.zone.local(2026, 8, 28, 12)) do
      described_class.call(
        approval_request:,
        actor: user,
        decision: "defer",
        lock_version: approval_request.lock_version,
        deferred_until: "2026-08-29T09:00"
      )

      expected = ActiveSupport::TimeZone["America/Costa_Rica"].parse("2026-08-29T09:00")
      expect(approval_request.reload.deferred_until).to eq(expected)
    end
  end

  it "dismisses the queue item without changing the source" do
    described_class.call(approval_request:, actor: user, decision: "dismiss", lock_version: approval_request.lock_version)

    expect(approval_request.reload.status).to eq("dismissed")
    expect(proposal.reload.status).to eq("pending")
  end

  it "approves a blocked memory for future high-impact consideration without performing an action" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    request_record = create(
      :approval_request,
      user:,
      subject: memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )

    expect do
      described_class.call(approval_request: request_record, actor: user, decision: "approve", lock_version: request_record.lock_version)
    end.not_to change { user.audit_events.where(action: "automation.performed").count }

    expect(memory.reload.high_impact_automation_approved_at).to be_present
    expect(request_record.reload.status).to eq("approved")
  end

  it "rejects approval when the memory is protected by the privacy vault" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    request_record = create(
      :approval_request,
      user:,
      subject: memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )
    PrivacyVault::Protect.call(actor: user, protectable: memory)

    expect do
      described_class.call(
        approval_request: request_record,
        actor: user,
        decision: "approve",
        lock_version: request_record.lock_version
      )
    end.to raise_error(Pundit::NotAuthorizedError)

    expect(memory.reload.high_impact_automation_approved_at).to be_nil
    expect(request_record.reload.status).to eq("pending")
  end

  it "rejects a decision when the reviewed source changed" do
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
    request_record = create(
      :approval_request,
      user:,
      subject: memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low"
    )
    memory.update!(body: "Materially revised source")

    expect do
      described_class.call(
        approval_request: request_record,
        actor: user,
        decision: "approve",
        lock_version: request_record.lock_version
      )
    end.to raise_error(ActiveRecord::StaleObjectError)

    expect(memory.reload.high_impact_automation_approved_at).to be_nil
  end

  it "uses the refreshed request version when explicitly reviewing a changed source" do
    approval_request
    proposal.update!(body: "Materially revised suggestion")

    expect do
      described_class.call(
        approval_request:,
        actor: user,
        decision: "approve",
        lock_version: approval_request.lock_version,
        override_source_version: true
      )
    end.to change(MemoryRecord, :count).by(1)

    expect(approval_request.reload).to have_attributes(status: "approved", subject_updated_at: proposal.updated_at)
    expect(proposal.reload.status).to eq("approved")
  end

  it "does not finalize an extracted-memory request before its deferral is due" do
    approval_request.update!(status: "deferred", deferred_until: 1.day.from_now)

    expect do
      described_class.call(
        approval_request:,
        actor: user,
        decision: "approve",
        lock_version: approval_request.lock_version
      )
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(approval_request.reload.status).to eq("deferred")
    expect(proposal.reload.status).to eq("pending")
  end

  it "fails closed across owner boundaries and on stale forms" do
    expect do
      described_class.call(approval_request:, actor: create(:user), decision: "approve", lock_version: approval_request.lock_version)
    end.to raise_error(Pundit::NotAuthorizedError)

    approval_request.update!(status: "deferred", deferred_until: 1.day.from_now)
    expect do
      described_class.call(approval_request:, actor: user, decision: "approve", lock_version: 0)
    end.to raise_error(ActiveRecord::StaleObjectError)
    expect(proposal.reload.status).to eq("pending")
  end

  it "rejects decisions after the relationship is archived" do
    profile.archive!

    expect do
      described_class.call(
        approval_request:,
        actor: user,
        decision: "approve",
        lock_version: approval_request.lock_version
      )
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(approval_request.reload.status).to eq("pending")
    expect(proposal.reload.status).to eq("pending")
  end

  it "normalizes a missing lock version to invalid input" do
    expect do
      described_class.call(approval_request:, actor: user, decision: "approve", lock_version: nil)
    end.to raise_error(ArgumentError, "Invalid lock version")
  end
end
