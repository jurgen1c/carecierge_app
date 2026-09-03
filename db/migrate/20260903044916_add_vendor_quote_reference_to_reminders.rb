class AddVendorQuoteReferenceToReminders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :reminders, :vendor_quote_id, :uuid unless column_exists?(:reminders, :vendor_quote_id)
    ensure_valid_index(:reminders, :vendor_quote_id)

    unless foreign_key_exists?(:reminders, :vendor_quotes, column: :vendor_quote_id)
      add_foreign_key :reminders, :vendor_quotes,
        column: :vendor_quote_id,
        on_delete: :nullify,
        validate: false
    end

    validate_foreign_key :reminders, :vendor_quotes, column: :vendor_quote_id
  end

  def down
    remove_foreign_key :reminders, column: :vendor_quote_id if foreign_key_exists?(:reminders, :vendor_quotes, column: :vendor_quote_id)
    remove_index :reminders, :vendor_quote_id, algorithm: :concurrently if index_exists?(:reminders, :vendor_quote_id)
    remove_column :reminders, :vendor_quote_id if column_exists?(:reminders, :vendor_quote_id)
  end

  private

  def ensure_valid_index(table, column)
    return if index_exists?(table, column, valid: true)

    remove_index table, column, algorithm: :concurrently if index_exists?(table, column)
    add_index table, column, algorithm: :concurrently
  end
end
