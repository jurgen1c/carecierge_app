class AddRecurrenceAnchorToReminders < ActiveRecord::Migration[8.1]
  def up
    add_column :reminders, :recurrence_anchor_at, :datetime
    execute "UPDATE reminders SET recurrence_anchor_at = scheduled_at"
    change_column_null :reminders, :recurrence_anchor_at, false
  end

  def down
    remove_column :reminders, :recurrence_anchor_at
  end
end
