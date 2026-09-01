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

  it "renders queued and decision evidence in the owner's time zone" do
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile)
    )
    queued_at = Time.utc(2026, 8, 29, 2, 30)
    occurred_at = Time.utc(2026, 8, 29, 3, 45)
    request_record = create(
      :approval_request,
      user:,
      subject: proposal,
      status: "dismissed",
      decided_at: occurred_at,
      created_at: queued_at
    )
    ApprovalDecision.create!(approval_request: request_record, user:, decision: "dismiss", occurred_at:)
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]

    render_inline(described_class.new(item: ApprovalQueue::Item.new(approval_request: request_record)))

    expect(page).to have_text(I18n.l(queued_at.in_time_zone(zone), format: :approval))
    expect(page).to have_text(I18n.l(occurred_at.in_time_zone(zone), format: :approval))
    expect(page).not_to have_text(I18n.l(queued_at, format: :approval))
    expect(page).not_to have_text(I18n.l(occurred_at, format: :approval))
  end

  it "shows a deferred item's owner-local return time in English and Spanish" do
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile)
    )
    deferred_until = Time.utc(2026, 8, 30, 2, 30)
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]

    Timecop.freeze(Time.utc(2026, 8, 29, 12)) do
      request_record = create(
        :approval_request,
        user:,
        subject: proposal,
        status: "deferred",
        deferred_until:
      )
      item = ApprovalQueue::Item.new(approval_request: request_record)

      %i[en es].each do |locale|
        I18n.with_locale(locale) do
          render_inline(described_class.new(item:))

          date = I18n.l(deferred_until.in_time_zone(zone), format: :approval)
          expect(page).to have_text(I18n.t("approvals.detail.deferred_until", date:))
          expect(page).not_to have_text(I18n.l(deferred_until, format: :approval))
        end
      end
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
