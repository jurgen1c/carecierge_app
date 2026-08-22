class AddEventPlanReferencesToReminders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :reminders, :event_plan_id, :uuid unless column_exists?(:reminders, :event_plan_id)
    add_column :reminders, :plan_task_id, :uuid unless column_exists?(:reminders, :plan_task_id)

    ensure_valid_index(:reminders, :event_plan_id)
    ensure_valid_index(:reminders, :plan_task_id)

    unless foreign_key_exists?(:reminders, :event_plans, column: :event_plan_id)
      add_foreign_key :reminders, :event_plans,
        column: :event_plan_id,
        on_delete: :cascade,
        validate: false
    end
    unless foreign_key_exists?(:reminders, :plan_tasks, column: :plan_task_id)
      add_foreign_key :reminders, :plan_tasks,
        column: :plan_task_id,
        on_delete: :nullify,
        validate: false
    end

    validate_foreign_key :reminders, :event_plans, column: :event_plan_id
    validate_foreign_key :reminders, :plan_tasks, column: :plan_task_id
  end

  def down
    remove_foreign_key :reminders, column: :plan_task_id if foreign_key_exists?(:reminders, :plan_tasks, column: :plan_task_id)
    remove_foreign_key :reminders, column: :event_plan_id if foreign_key_exists?(:reminders, :event_plans, column: :event_plan_id)
    remove_index :reminders, :plan_task_id, algorithm: :concurrently if index_exists?(:reminders, :plan_task_id)
    remove_index :reminders, :event_plan_id, algorithm: :concurrently if index_exists?(:reminders, :event_plan_id)
    remove_column :reminders, :plan_task_id if column_exists?(:reminders, :plan_task_id)
    remove_column :reminders, :event_plan_id if column_exists?(:reminders, :event_plan_id)
  end

  private

  def ensure_valid_index(table, column)
    return if index_exists?(table, column, valid: true)

    remove_index table, column, algorithm: :concurrently if index_exists?(table, column)
    add_index table, column, algorithm: :concurrently
  end
end
