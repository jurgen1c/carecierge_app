class AddBookingContextToReminders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :reminders, :booking_id, :uuid unless column_exists?(:reminders, :booking_id)
    add_column :reminders, :booking_milestone, :string unless column_exists?(:reminders, :booking_milestone)
    ensure_valid_index(:reminders, :booking_id)

    unless foreign_key_exists?(:reminders, :bookings, column: :booking_id)
      add_foreign_key :reminders, :bookings,
        column: :booking_id,
        on_delete: :nullify,
        validate: false
    end

    validate_foreign_key :reminders, :bookings, column: :booking_id
  end

  def down
    remove_foreign_key :reminders, column: :booking_id if foreign_key_exists?(:reminders, :bookings, column: :booking_id)
    remove_index :reminders, :booking_id, algorithm: :concurrently if index_exists?(:reminders, :booking_id)
    remove_column :reminders, :booking_milestone if column_exists?(:reminders, :booking_milestone)
    remove_column :reminders, :booking_id if column_exists?(:reminders, :booking_id)
  end

  private

  def ensure_valid_index(table, column)
    return if index_exists?(table, column, valid: true)

    remove_index table, column, algorithm: :concurrently if index_exists?(table, column)
    add_index table, column, algorithm: :concurrently
  end
end
