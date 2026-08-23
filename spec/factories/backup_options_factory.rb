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
FactoryBot.define do
  factory :backup_option do
    association :backup_plan
    sequence(:title) { |number| "Backup option #{number}" }
    summary { "A calm alternative that keeps the important details." }
    effort { "low" }
    timing { "same_day" }
    estimated_cost_cents { 15_000 }
    cost_level { "similar" }
    relationship_fit { "strong" }
    preserved_constraints { [ "Budget", "Guest list" ] }
    change_summary { [ "Venue" ] }
    task_blueprints do
      [
        {
          "phase" => "arrange",
          "kind" => "backup_step",
          "title" => "Confirm the backup venue",
          "details" => "Review availability before committing.",
          "due_on" => "2026-09-10",
          "source_context" => backup_plan.source_context
        }
      ]
    end
    replacement_task_ids { [] }
    reviewed_reminders do
      Reminder.active.where(plan_task_id: replacement_task_ids).reorder(:id).map do |reminder|
        BackupOption.reminder_snapshot(reminder)
      end
    end
    source_context { backup_plan.source_context }
    sequence(:position) { |number| number - 1 }
  end
end
