# == Schema Information
#
# Table name: notification_preferences
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  digest_mode                  :string           default("off"), not null
#  digest_time                  :time             default(2000-01-01 09:00:00.000000000 UTC +00:00), not null
#  digest_weekday               :integer          default(1), not null
#  email_enabled                :boolean          default(TRUE), not null
#  high_priority_alerts_enabled :boolean          default(TRUE), not null
#  in_app_enabled               :boolean          default(TRUE), not null
#  push_enabled                 :boolean          default(FALSE), not null
#  quiet_hours_enabled          :boolean          default(FALSE), not null
#  quiet_hours_end              :time             default(2000-01-01 07:00:00.000000000 UTC +00:00), not null
#  quiet_hours_start            :time             default(2000-01-01 22:00:00.000000000 UTC +00:00), not null
#  reminder_frequency           :string           default("none"), not null
#  reminder_lead_minutes        :integer          default(1440), not null
#  sms_enabled                  :boolean          default(FALSE), not null
#  time_zone                    :string           default("UTC"), not null
#  time_zone_configured         :boolean          default(FALSE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  user_id                      :uuid             not null
#
# Indexes
#
#  index_notification_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe NotificationPreference, type: :model do
  it "defaults to enabled in-app and email delivery while reserving future channels" do
    preference = described_class.new

    expect(preference).to have_attributes(
      in_app_enabled: true,
      email_enabled: true,
      push_enabled: false,
      sms_enabled: false,
      quiet_hours_enabled: false,
      high_priority_alerts_enabled: true,
      reminder_frequency: "none",
      reminder_lead_minutes: 1_440,
      digest_mode: "off",
      digest_weekday: 1,
      time_zone: "UTC"
    )
  end

  describe ".channels_for" do
    it "uses enabled defaults before a user saves preferences" do
      user = create(:user)

      expect(described_class.channels_for(user)).to eq(%w[in_app email])
    end

    it "returns only saved enabled channels" do
      user = create(:user)
      create(:notification_preference, user:, in_app_enabled: true, email_enabled: false)

      expect(described_class.channels_for(user)).to eq([ "in_app" ])
    end

    it "does not dispatch reserved future channels" do
      user = create(:user)
      create(:notification_preference, user:, push_enabled: true, sms_enabled: true)

      expect(described_class.channels_for(user)).to eq(%w[in_app email])
    end

    it "uses a preloaded preference without querying again" do
      user = create(:user)
      create(:notification_preference, user:, email_enabled: false)
      loaded_user = User.includes(:notification_preference).find(user.id)

      expect(described_class).not_to receive(:find_by)
      expect(described_class.channels_for(loaded_user)).to eq([ "in_app" ])
    end

    it "keeps a muted relationship occurrence pending" do
      user = create(:user)
      preference = create(:notification_preference, user:)
      profile = create(:relationship_profile, user:)
      reminder = create(:reminder, user:, relationship_profile: profile)
      create(:relationship_notification_preference, notification_preference: preference, relationship_profile: profile, mode: "muted")

      expect(described_class.channels_for(user, reminder:)).to be_empty
    end

    it "ignores a hidden mute override after its relationship is archived" do
      user = create(:user)
      preference = create(:notification_preference, user:)
      profile = create(:relationship_profile, user:)
      reminder = create(:reminder, user:, relationship_profile: profile)
      create(:relationship_notification_preference, notification_preference: preference, relationship_profile: profile, mode: "muted")

      profile.archive!

      expect(described_class.channels_for(user, reminder:)).to eq(%w[in_app email])
    end
  end

  describe "quiet hours" do
    let(:preference) do
      build(
        :notification_preference,
        quiet_hours_enabled: true,
        quiet_hours_start: "21:00",
        quiet_hours_end: "07:00",
        time_zone: "America/Costa_Rica"
      )
    end

    it "defers ordinary reminders to the next local quiet-hours end" do
      reminder = build(:reminder, priority: "normal")
      local_time = ActiveSupport::TimeZone["America/Costa_Rica"].local(2026, 7, 15, 22, 30)

      expect(preference.delivery_deferred_until(reminder, at: local_time))
        .to eq(ActiveSupport::TimeZone["America/Costa_Rica"].local(2026, 7, 16, 7, 0))
    end

    it "allows configured high-priority reminders through quiet hours" do
      reminder = build(:reminder, priority: "high")
      local_time = ActiveSupport::TimeZone["America/Costa_Rica"].local(2026, 7, 15, 22, 30)

      expect(preference.delivery_deferred_until(reminder, at: local_time)).to be_nil
    end

    it "defers high-priority reminders when their bypass is disabled" do
      preference.high_priority_alerts_enabled = false
      reminder = build(:reminder, priority: "high")
      local_time = ActiveSupport::TimeZone["America/Costa_Rica"].local(2026, 7, 15, 22, 30)

      expect(preference.delivery_deferred_until(reminder, at: local_time)).to be_present
    end

    it "does not defer outside quiet hours" do
      reminder = build(:reminder, priority: "normal")
      local_time = ActiveSupport::TimeZone["America/Costa_Rica"].local(2026, 7, 15, 12, 0)

      expect(preference.delivery_deferred_until(reminder, at: local_time)).to be_nil
    end

    it "uses the upcoming repeated quiet-hours boundary after daylight saving fallback" do
      preference.time_zone = "America/New_York"
      preference.quiet_hours_start = "00:00"
      preference.quiet_hours_end = "01:30"
      reminder = build(:reminder, priority: "normal")
      local_time = Time.utc(2026, 11, 1, 6, 0).in_time_zone(preference.time_zone)

      expect(preference.delivery_deferred_until(reminder, at: local_time))
        .to eq(Time.utc(2026, 11, 1, 6, 30).in_time_zone(preference.time_zone))
    end
  end

  it "validates the time fields required by the database" do
    preference = build(:notification_preference, quiet_hours_start: nil, quiet_hours_end: nil, digest_time: nil)

    expect(preference).not_to be_valid
    expect(preference.errors).to include(:quiet_hours_start, :quiet_hours_end, :digest_time)
  end
end
