class AddCalendarConnectionGenerationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :calendar_connection_generation, :integer, null: false, default: 0
    add_check_constraint :users,
      "calendar_connection_generation >= 0",
      name: "users_calendar_connection_generation_nonnegative"
  end
end
