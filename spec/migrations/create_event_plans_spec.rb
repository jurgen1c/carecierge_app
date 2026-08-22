require "rails_helper"

RSpec.describe "CreateEventPlans migration" do
  it "keeps table creation transactional and moves recoverable online reminder DDL into a follow-up" do
    table_source = Rails.root.join("db/migrate/20260821040000_create_event_plans.rb").read
    reminder_source = Rails.root.join("db/migrate/20260821040001_add_event_plan_references_to_reminders.rb").read
    schema_source = Rails.root.join("db/schema.rb").read

    expect(table_source).not_to include("disable_ddl_transaction!")
    expect(table_source).not_to include(":reminders")
    expect(reminder_source).to include("disable_ddl_transaction!")
    expect(reminder_source.scan("algorithm: :concurrently").length).to eq(4)
    expect(reminder_source.scan("validate: false").length).to eq(2)
    expect(reminder_source.scan("validate_foreign_key :reminders").length).to eq(2)
    expect(reminder_source).to include("index_exists?(table, column, valid: true)")
    expect(reminder_source).to include("remove_index table, column, algorithm: :concurrently")
    expect(reminder_source).to include("column_exists?", "index_exists?", "foreign_key_exists?")
    expect(reminder_source).not_to include("add_reference :reminders")
    expect(schema_source).to include('add_foreign_key "reminders", "plan_tasks", on_delete: :nullify')
  end
end
