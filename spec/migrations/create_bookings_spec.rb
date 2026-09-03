require "rails_helper"

RSpec.describe "Booking migrations" do
  it "uses UUID ownership keys and a resumable concurrent reminder follow-up" do
    table_source = Rails.root.join("db/migrate/20260903120000_create_bookings.rb").read
    reminder_source = Rails.root.join("db/migrate/20260903121000_add_booking_context_to_reminders.rb").read
    schema_source = Rails.root.join("db/schema.rb").read

    expect(table_source).to include("create_table :bookings, id: :uuid")
    expect(table_source).to include("t.references :user, null: false, type: :uuid")
    expect(table_source).to include("t.references :event_plan, null: false, type: :uuid")
    expect(table_source).to include("t.references :plan_task, null: true, type: :uuid")
    expect(table_source).not_to include("disable_ddl_transaction!")
    expect(table_source).not_to include(":reminders")

    expect(reminder_source).to include("disable_ddl_transaction!")
    expect(reminder_source.scan("algorithm: :concurrently").length).to be >= 2
    expect(reminder_source).to include("validate: false")
    expect(reminder_source).to include("validate_foreign_key :reminders, :bookings")
    expect(reminder_source).to include("column_exists?", "index_exists?", "foreign_key_exists?")
    expect(schema_source).to include('add_foreign_key "reminders", "bookings", on_delete: :nullify')
  end
end
