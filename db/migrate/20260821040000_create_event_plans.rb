class CreateEventPlans < ActiveRecord::Migration[8.1]
  def up
    create_table :event_plans, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :title, null: false
      t.string :occasion_type, null: false
      t.date :starts_on
      t.integer :budget_cents
      t.text :guest_list
      t.text :notes
      t.text :source_context, null: false
      t.string :status, null: false, default: "active"
      t.datetime :completed_at
      t.bigint :generation_version, null: false, default: 0
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :event_plans, %i[user_id status starts_on]
    add_index :event_plans, %i[relationship_profile_id status starts_on], name: "index_event_plans_on_profile_status_and_start"
    add_check_constraint :event_plans,
      "status IN ('active', 'completed', 'archived')",
      name: "event_plans_supported_status"
    add_check_constraint :event_plans,
      "budget_cents IS NULL OR budget_cents >= 0",
      name: "event_plans_budget_nonnegative"

    create_table :plan_tasks, id: :uuid do |t|
      t.references :event_plan, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :phase, null: false
      t.string :kind, null: false
      t.text :title, null: false
      t.text :details
      t.date :due_on
      t.integer :position, null: false
      t.string :origin, null: false, default: "manual"
      t.text :source_context, null: false
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :plan_tasks, %i[event_plan_id phase position], name: "index_plan_tasks_on_plan_phase_position"
    add_index :plan_tasks, %i[event_plan_id completed_at due_on], name: "index_plan_tasks_on_plan_completion_and_due"
    add_check_constraint :plan_tasks,
      "phase IN ('decide', 'arrange', 'follow_through')",
      name: "plan_tasks_supported_phase"
    add_check_constraint :plan_tasks,
      "kind IN ('decision', 'task', 'reminder', 'vendor_need', 'gift_idea', 'message_draft', 'backup_step', 'milestone')",
      name: "plan_tasks_supported_kind"
    add_check_constraint :plan_tasks,
      "origin IN ('manual', 'template', 'ai')",
      name: "plan_tasks_supported_origin"
    add_check_constraint :plan_tasks,
      "position >= 0",
      name: "plan_tasks_position_nonnegative"
  end

  def down
    drop_table :plan_tasks
    drop_table :event_plans
  end
end
