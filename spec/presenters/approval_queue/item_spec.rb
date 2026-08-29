require "rails_helper"

RSpec.describe ApprovalQueue::Item do
  it "presents the corrected extracted-memory title in completed history" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile),
      title: "Likes jazz",
      status: "corrected",
      corrected_title: "Enjoys intimate live jazz",
      corrected_body: "Enjoys intimate live jazz for special evenings."
    )
    approval_request = create(:approval_request, user:, subject: proposal, status: "approved", decided_at: Time.current)

    item = described_class.new(approval_request:)

    expect(item.title).to eq("Enjoys intimate live jazz")
    expect(item.proposed_action).to include("Enjoys intimate live jazz")
    expect(item.proposed_action).not_to include("Likes jazz")
  end

  it "does not bind changed live source content to an earlier completed decision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    memory = create(
      :memory_record,
      relationship_profile: profile,
      title: "Original private detail",
      body: "Original private context",
      source: "ai_inferred",
      confidence: "low"
    )
    approval_request = create(
      :approval_request,
      user:,
      subject: memory,
      kind: "memory_record",
      action_key: "approve_high_impact_memory",
      risk_level: "high",
      confidence: "low",
      status: "rejected",
      decided_at: Time.current
    )
    memory.update!(title: "Later private detail", body: "Later private context")

    item = described_class.new(approval_request:)

    expect(item).to be_source_changed_since_review
    expect(item.title).to eq(I18n.t("approvals.detail.source_changed_title"))
    expect(item.source_label).to eq(I18n.t("approvals.detail.source_changed_source"))
    expect(item.source_context).to eq(I18n.t("approvals.detail.source_changed_context"))
    expect(item.proposed_action).to eq(I18n.t("approvals.detail.source_changed_action"))
    expect([ item.title, item.source_label, item.source_context, item.proposed_action ].join).not_to include(
      "Later private detail",
      "Later private context"
    )
  end

  it "does not render a mutable recap title as completed extracted-memory history" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    recap = create(:conversation_recap, relationship_profile: profile, title: "Original private recap")
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    approval_request = create(
      :approval_request,
      user:,
      subject: proposal,
      status: "rejected",
      decided_at: Time.current
    )
    recap.update!(title: "Later private recap")

    item = described_class.new(approval_request:)

    expect(item).not_to be_source_changed_since_review
    expect(item.source_label).to eq(I18n.t("approvals.detail.reviewed_source"))
    expect(item.source_label).not_to include("Later private recap")
  end

  it "presents superseded work as an automatic queue transition, not a user decision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile)
    )
    approval_request = create(
      :approval_request,
      user:,
      subject: proposal,
      status: "superseded",
      decided_at: Time.current
    )
    proposal.update!(body: "Later private source content")

    item = described_class.new(approval_request:)

    expect(item).to be_superseded
    expect(item).not_to be_source_changed_since_review
    expect(item.title).to eq(I18n.t("approvals.detail.superseded_title"))
    expect(item.source_label).to eq(I18n.t("approvals.detail.superseded_source"))
    expect(item.source_context).to eq(I18n.t("approvals.detail.superseded_context"))
    expect(item.proposed_action).to eq(I18n.t("approvals.detail.superseded_action"))
    expect(item.consequence).to eq(I18n.t("approvals.detail.superseded_consequence"))
    expect(item.will_not_happen).to eq(I18n.t("approvals.detail.superseded_will_not_happen"))
    expect(item.reversible).to eq(I18n.t("approvals.detail.superseded_reversibility"))
    expect(item.source_context).not_to include("Later private source content")
  end
end
