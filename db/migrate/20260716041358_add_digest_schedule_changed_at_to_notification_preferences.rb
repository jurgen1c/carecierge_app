class AddDigestScheduleChangedAtToNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_preferences, :digest_schedule_changed_at, :datetime
  end
end
