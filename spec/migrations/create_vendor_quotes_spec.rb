require "rails_helper"

RSpec.describe "Vendor quote migrations" do
  it "keeps table creation transactional and moves reminder DDL into a resumable concurrent follow-up" do
    table_source = Rails.root.join("db/migrate/20260903042850_create_vendor_quotes.rb").read
    reminder_source = Rails.root.join("db/migrate/20260903044916_add_vendor_quote_reference_to_reminders.rb").read
    schema_source = Rails.root.join("db/schema.rb").read

    expect(table_source).not_to include("disable_ddl_transaction!")
    expect(table_source).not_to include(":reminders")
    expect(reminder_source).to include("disable_ddl_transaction!")
    expect(reminder_source.scan("algorithm: :concurrently").length).to eq(3)
    expect(reminder_source.scan("validate: false").length).to eq(1)
    expect(reminder_source.scan("validate_foreign_key :reminders").length).to eq(1)
    expect(reminder_source).to include("index_exists?(table, column, valid: true)")
    expect(reminder_source).to include("remove_index table, column, algorithm: :concurrently")
    expect(reminder_source).to include("column_exists?", "index_exists?", "foreign_key_exists?")
    expect(reminder_source).not_to include("add_reference :reminders")
    expect(schema_source).to include('add_foreign_key "reminders", "vendor_quotes", on_delete: :nullify')
  end
end
