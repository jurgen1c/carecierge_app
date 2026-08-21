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
end
