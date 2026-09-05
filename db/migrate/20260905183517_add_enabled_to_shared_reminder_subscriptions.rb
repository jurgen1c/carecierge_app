class AddEnabledToSharedReminderSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :shared_reminder_subscriptions, :enabled, :boolean, default: true, null: false
  end
end
