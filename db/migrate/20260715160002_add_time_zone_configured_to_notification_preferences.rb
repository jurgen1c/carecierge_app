class AddTimeZoneConfiguredToNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_preferences, :time_zone_configured, :boolean, null: false, default: false
  end
end
