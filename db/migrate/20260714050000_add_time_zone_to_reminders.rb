class AddTimeZoneToReminders < ActiveRecord::Migration[8.1]
  def change
    add_column :reminders, :time_zone, :string, null: false, default: "UTC"
  end
end
