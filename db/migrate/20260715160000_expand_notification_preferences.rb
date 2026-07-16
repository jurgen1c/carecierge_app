class ExpandNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    change_table :notification_preferences, bulk: true do |t|
      t.boolean :quiet_hours_enabled, null: false, default: false
      t.time :quiet_hours_start, null: false, default: "22:00:00"
      t.time :quiet_hours_end, null: false, default: "07:00:00"
      t.string :time_zone, null: false, default: "UTC"
      t.boolean :high_priority_alerts_enabled, null: false, default: true
      t.string :reminder_frequency, null: false, default: "none"
      t.integer :reminder_lead_minutes, null: false, default: 1_440
      t.string :digest_mode, null: false, default: "off"
      t.time :digest_time, null: false, default: "09:00:00"
      t.integer :digest_weekday, null: false, default: 1
    end

    add_check_constraint :notification_preferences,
      "reminder_frequency IN ('none', 'daily', 'weekly', 'monthly', 'yearly')",
      name: "notification_preferences_supported_reminder_frequency"
    add_check_constraint :notification_preferences,
      "reminder_lead_minutes IN (0, 60, 1440, 10080, 20160, 43200)",
      name: "notification_preferences_supported_reminder_lead"
    add_check_constraint :notification_preferences,
      "digest_mode IN ('off', 'daily', 'weekly')",
      name: "notification_preferences_supported_digest_mode"
    add_check_constraint :notification_preferences,
      "digest_weekday BETWEEN 0 AND 6",
      name: "notification_preferences_supported_digest_weekday"
  end
end
