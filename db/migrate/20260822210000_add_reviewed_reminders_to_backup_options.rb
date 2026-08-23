class AddReviewedRemindersToBackupOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :backup_options, :reviewed_reminders, :text, null: false, default: "[]"
    change_column_default :backup_options, :reviewed_reminders, from: "[]", to: nil
  end
end
