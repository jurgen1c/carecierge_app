class AddBackupOptionReferenceToPlanTasks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :plan_tasks, :backup_option_id, :uuid unless column_exists?(:plan_tasks, :backup_option_id)
    add_column :plan_tasks, :superseded_at, :datetime unless column_exists?(:plan_tasks, :superseded_at)

    ensure_valid_index(:plan_tasks, :backup_option_id)
    ensure_valid_index(
      :plan_tasks,
      %i[event_plan_id superseded_at],
      name: "index_plan_tasks_on_plan_and_superseded"
    )

    unless foreign_key_exists?(:plan_tasks, :backup_options, column: :backup_option_id)
      add_foreign_key :plan_tasks,
        :backup_options,
        column: :backup_option_id,
        on_delete: :nullify,
        validate: false
    end
    validate_foreign_key :plan_tasks, :backup_options, column: :backup_option_id
  end

  def down
    if foreign_key_exists?(:plan_tasks, :backup_options, column: :backup_option_id)
      remove_foreign_key :plan_tasks, column: :backup_option_id
    end
    remove_valid_index(:plan_tasks, %i[event_plan_id superseded_at], name: "index_plan_tasks_on_plan_and_superseded")
    remove_valid_index(:plan_tasks, :backup_option_id)
    remove_column :plan_tasks, :superseded_at if column_exists?(:plan_tasks, :superseded_at)
    remove_column :plan_tasks, :backup_option_id if column_exists?(:plan_tasks, :backup_option_id)
  end

  private

  def ensure_valid_index(table, columns, name: nil)
    options = name ? { name: } : {}
    return if index_exists?(table, columns, valid: true, **options)

    remove_index table, columns, algorithm: :concurrently, **options if index_exists?(table, columns, **options)
    add_index table, columns, algorithm: :concurrently, **options
  end

  def remove_valid_index(table, columns, name: nil)
    options = name ? { name: } : {}
    remove_index table, columns, algorithm: :concurrently, **options if index_exists?(table, columns, **options)
  end
end
