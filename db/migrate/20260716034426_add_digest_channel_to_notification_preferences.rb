class AddDigestChannelToNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_preferences, :digest_channel, :string, null: false, default: "email"
    add_check_constraint :notification_preferences,
      "digest_channel IN ('email', 'in_app')",
      name: "notification_preferences_supported_digest_channel"
  end
end
