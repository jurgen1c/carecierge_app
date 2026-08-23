require "rails_helper"

RSpec.describe "Backup plan migrations" do
  it "uses UUID ownership and moves existing-table DDL into a resumable concurrent follow-up" do
    table_source = Rails.root.join("db/migrate/20260822191243_create_backup_plans.rb").read
    plan_tasks_source = Rails.root.join("db/migrate/20260822192636_add_backup_option_reference_to_plan_tasks.rb").read
    reminder_review_source = Rails.root.join("db/migrate/20260822210000_add_reviewed_reminders_to_backup_options.rb").read
    schema_source = Rails.root.join("db/schema.rb").read

    expect(table_source).to include("create_table :backup_plans, id: :uuid")
    expect(table_source).to include("create_table :backup_options, id: :uuid")
    expect(table_source).to include("type: :uuid")
    expect(table_source).to include("context_fingerprint", "backup_plans_context_fingerprint_format")
    expect(table_source).not_to include(":plan_tasks")
    expect(plan_tasks_source).to include("disable_ddl_transaction!")
    expect(plan_tasks_source.scan("algorithm: :concurrently").length).to be >= 2
    expect(plan_tasks_source).to include("validate: false", "validate_foreign_key")
    expect(plan_tasks_source).to include("column_exists?", "index_exists?", "foreign_key_exists?")
    expect(reminder_review_source).to include("reviewed_reminders", "null: false")
    expect(schema_source).to include('add_foreign_key "plan_tasks", "backup_options", on_delete: :nullify')
    expect(schema_source).to include('add_foreign_key "reminders", "plan_tasks", on_delete: :nullify')
  end
end
