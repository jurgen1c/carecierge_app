require "rails_helper"

RSpec.describe AuditEventPresenter do
  it "uses localized, type-aware labels without rendering reminder contents" do
    user = create(:user)
    reminder = create(:reminder, user:, title: "Private title", notes: "Private notes")
    event = create(:audit_event, user:, actor: user, action: "reminder.created", target: reminder)

    presenter = described_class.new(event)

    expect(presenter.title).to eq(I18n.t("audit_events.actions.reminder_created.title"))
    expect(presenter.description).to include(I18n.t("audit_events.targets.reminder"))
    expect(presenter.description).not_to include("Private title", "Private notes")
    expect(presenter.tone).to eq(:standard)
  end

  it "uses the deleted-resource fallback after target nullification" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    event = create(:audit_event, user:, actor: user, target: profile)
    profile.destroy!

    expect(described_class.new(event.reload).target_label).to eq(I18n.t("audit_events.targets.deleted_resource"))
  end

  it "has complete English and Spanish labels for gift recommendation actions" do
    action_keys = %w[
      gift_recommendation_generated
      gift_recommendation_saved
      gift_recommendation_dismissed
      gift_recommendation_purchased
    ]

    %i[en es].product(action_keys, %w[title description]).each do |locale, action_key, attribute|
      expect(I18n.exists?("audit_events.actions.#{action_key}.#{attribute}", locale)).to be(true)
    end
  end

  it "has complete English and Spanish labels for event planning suggestions" do
    plan = create(:event_plan)
    event = create(
      :audit_event,
      user: plan.user,
      actor: plan.user,
      action: "event_plan.suggestions_generated",
      target: plan
    )

    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        presenter = described_class.new(event)
        expect(presenter.title).to eq(I18n.t("audit_events.actions.event_plan_suggestions_generated.title"))
        expected_target = { en: "Event plan", es: "Plan de evento" }.fetch(locale)
        expect(I18n.exists?("audit_events.targets.event_plan", locale)).to be(true)
        expect(presenter.target_label).to eq(expected_target)
      end
    end
  end

  it "has complete English and Spanish labels for every approval action" do
    action_keys = %w[approval_granted approval_rejected approval_deferred approval_dismissed]

    %i[en es].product(action_keys, %w[title description]).each do |locale, action_key, attribute|
      expect(I18n.exists?("audit_events.actions.#{action_key}.#{attribute}", locale)).to be(true)
    end
  end

  it "has content-free English and Spanish labels for calendar actions" do
    connection = create(:calendar_connection)
    event = create(
      :audit_event,
      user: connection.user,
      actor: connection.user,
      action: "calendar.settings.updated",
      target: connection,
      metadata: { changed_fields: "sync_types" }
    )
    action_keys = %w[
      calendar_connection_created
      calendar_connection_revoked
      calendar_connection_revocation_failed
      calendar_settings_updated
      calendar_sync_completed
      calendar_sync_failed
    ]

    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        presenter = described_class.new(event)
        expect(presenter.target_label).to eq(I18n.t("audit_events.targets.calendar_connection"))
        expect(presenter.description).not_to include(connection.access_token, connection.refresh_token)
      end
    end
    %i[en es].product(action_keys, %w[title description]).each do |locale, action_key, attribute|
      expect(I18n.exists?("audit_events.actions.#{action_key}.#{attribute}", locale)).to be(true)
    end
  end
end
