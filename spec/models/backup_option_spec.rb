require "rails_helper"

# == Schema Information
#
# Table name: backup_options
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  change_summary        :text             not null
#  cost_level            :string           not null
#  effort                :string           not null
#  estimated_cost_cents  :integer
#  lock_version          :integer          default(0), not null
#  position              :integer          not null
#  preserved_constraints :text             not null
#  promoted_at           :datetime
#  relationship_fit      :string           not null
#  replacement_task_ids  :text             not null
#  reviewed_reminders    :text             not null
#  source_context        :text             not null
#  summary               :text             not null
#  task_blueprints       :text             not null
#  timing                :string           not null
#  title                 :text             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  backup_plan_id        :uuid             not null
#
# Indexes
#
#  index_backup_options_on_backup_plan_id               (backup_plan_id)
#  index_backup_options_on_backup_plan_id_and_position  (backup_plan_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (backup_plan_id => backup_plans.id) ON DELETE => cascade
#
RSpec.describe BackupOption, type: :model do
  subject(:backup_option) { build(:backup_option) }

  it "belongs to a backup plan and retains promoted tasks when deleted" do
    expect(described_class.reflect_on_association(:backup_plan).macro).to eq(:belongs_to)
    tasks = described_class.reflect_on_association(:plan_tasks)
    expect(tasks.macro).to eq(:has_many)
    expect(tasks.options[:dependent]).to eq(:nullify)
  end

  it "validates comparison attributes" do
    backup_option.effort = "impossible"
    backup_option.timing = "eventually"
    backup_option.cost_level = "mystery"
    backup_option.relationship_fit = "unknown"

    expect(backup_option).not_to be_valid
    expect(backup_option.errors).to include(:effort, :timing, :cost_level, :relationship_fit)
  end

  it "requires structured preserved constraints, changes, tasks, and source provenance" do
    backup_option.preserved_constraints = []
    backup_option.change_summary = []
    backup_option.task_blueprints = []
    backup_option.source_context = []

    expect(backup_option).not_to be_valid
    expect(backup_option.errors).to include(:preserved_constraints, :change_summary, :task_blueprints, :source_context)
  end

  it "encrypts generated content, tasks, reminder impact, and provenance at rest" do
    backup_option = create(
      :backup_option,
      title: "Private indoor dinner",
      summary: "Keep the gathering quiet.",
      preserved_constraints: [ "Private mobility need" ],
      change_summary: [ "Move away from the outdoor patio" ],
      reviewed_reminders: [
        {
          "id" => SecureRandom.uuid,
          "plan_task_id" => SecureRandom.uuid,
          "title" => "Private terrace reminder",
          "scheduled_at" => "2026-09-01T15:00:00.000000Z",
          "snoozed_until" => nil,
          "time_zone" => "UTC",
          "recurrence" => "none",
          "reminder_type" => "event_preparation",
          "priority" => "normal"
        }
      ]
    )

    raw = ApplicationRecord.connection.select_one(
      ApplicationRecord.sanitize_sql_array([
        <<~SQL.squish,
          SELECT title, summary, preserved_constraints, change_summary, task_blueprints, reviewed_reminders, source_context
          FROM backup_options
          WHERE id = ?
        SQL
        backup_option.id
      ])
    )

    expect(raw.values.join(" ")).not_to include(
      "Private indoor dinner",
      "Keep the gathering quiet",
      "Private mobility need",
      "Confirm the backup venue",
      "Private terrace reminder"
    )
    expect(backup_option.reload.title).to eq("Private indoor dinner")
  end
end
