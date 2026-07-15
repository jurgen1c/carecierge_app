require "rails_helper"

RSpec.describe NotificationPreferences::Save do
  it "saves account settings and sparse muted relationship overrides atomically" do
    user = create(:user)
    muted_profile = create(:relationship_profile, user:)
    inherited_profile = create(:relationship_profile, user:)
    preference = user.build_notification_preference

    result = described_class.call(
      preference,
      attributes: { email_enabled: false, digest_mode: "weekly" },
      relationship_modes: {
        muted_profile.id => "muted",
        inherited_profile.id => "inherit"
      }
    )

    expect(result).to be(true)
    expect(preference.reload).to have_attributes(email_enabled: false, digest_mode: "weekly")
    expect(preference.relationship_notification_preferences.sole).to have_attributes(
      relationship_profile_id: muted_profile.id,
      mode: "muted"
    )
  end

  it "records that the saved timezone was explicitly configured" do
    preference = create(:notification_preference, time_zone_configured: false)

    described_class.call(
      preference,
      attributes: { time_zone: "America/Costa_Rica" },
      relationship_modes: {}
    )

    expect(preference.reload).to have_attributes(
      time_zone: "America/Costa_Rica",
      time_zone_configured: true
    )
  end

  it "removes an override when the relationship returns to account defaults" do
    user = create(:user)
    preference = create(:notification_preference, user:)
    profile = create(:relationship_profile, user:)
    create(:relationship_notification_preference, notification_preference: preference, relationship_profile: profile)

    expect do
      described_class.call(preference, attributes: {}, relationship_modes: { profile.id => "inherit" })
    end.to change(RelationshipNotificationPreference, :count).by(-1)
  end

  it "rejects another user's relationship without changing account settings" do
    preference = create(:notification_preference, email_enabled: true)
    foreign_profile = create(:relationship_profile)

    expect do
      described_class.call(
        preference,
        attributes: { email_enabled: false },
        relationship_modes: { foreign_profile.id => "muted" }
      )
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(preference.reload.email_enabled).to be(true)
  end

  it "releases due reminders for immediate reevaluation when quiet-hour rules change" do
    now = Time.zone.local(2026, 7, 15, 22, 0)
    preference = create(:notification_preference, quiet_hours_enabled: true)
    reminder = create(
      :reminder,
      user: preference.user,
      relationship_profile: create(:relationship_profile, user: preference.user),
      scheduled_at: now - 1.hour,
      next_delivery_at: now + 9.hours
    )

    Timecop.freeze(now) do
      described_class.call(preference, attributes: { quiet_hours_enabled: false })
    end

    expect(reminder.reload.next_delivery_at).to eq(reminder.scheduled_at)
  end
end
