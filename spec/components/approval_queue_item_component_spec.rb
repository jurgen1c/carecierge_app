require "rails_helper"

RSpec.describe ApprovalQueueItemComponent, type: :component do
  it "rounds the deferral minimum up to a future whole minute" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile)
    )
    request_record = create(:approval_request, user:, subject: proposal)
    item = ApprovalQueue::Item.new(approval_request: request_record)

    Timecop.freeze(Time.zone.local(2026, 8, 29, 12, 0, 45)) do
      component = described_class.new(item:)

      expect(component.deferral_min).to eq("2026-08-29T12:02")
    end
  end

  it "explains an automatic supersession without inventing decision history" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile)
    )
    request_record = create(
      :approval_request,
      user:,
      subject: proposal,
      status: "superseded",
      decided_at: Time.current
    )
    item = ApprovalQueue::Item.new(approval_request: request_record)

    render_inline(described_class.new(item:))

    expect(page).to have_text(I18n.t("approvals.detail.superseded_completed", status: I18n.t("approvals.statuses.superseded")))
    expect(page).to have_text(I18n.t("approvals.history.superseded"))
    expect(page).not_to have_text(I18n.t("approvals.detail.completed", status: I18n.t("approvals.statuses.superseded")))
    expect(page).not_to have_text(I18n.t("approvals.history.queued", date: I18n.l(request_record.created_at, format: :approval)))
  end
end
