class CreateBackupPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_plans, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :event_plan, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :scenario, null: false
      t.text :source_context, null: false
      t.string :locale, null: false, default: "en"
      t.boolean :include_private_notes, null: false, default: false
      t.boolean :include_vault_context, null: false, default: false
      t.string :status, null: false, default: "generated"
      t.bigint :event_plan_generation_version, null: false
      t.string :context_fingerprint, null: false, limit: 64
      t.datetime :generated_at, null: false
      t.datetime :promoted_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    create_table :backup_options, id: :uuid do |t|
      t.references :backup_plan, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :title, null: false
      t.text :summary, null: false
      t.string :effort, null: false
      t.string :timing, null: false
      t.integer :estimated_cost_cents
      t.string :cost_level, null: false
      t.string :relationship_fit, null: false
      t.text :preserved_constraints, null: false
      t.text :change_summary, null: false
      t.text :task_blueprints, null: false
      t.text :replacement_task_ids, null: false
      t.text :source_context, null: false
      t.integer :position, null: false
      t.datetime :promoted_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :backup_plans,
      %i[event_plan_id status generated_at],
      name: "index_backup_plans_on_plan_status_generated"
    add_index :backup_options, %i[backup_plan_id position], unique: true
    add_check_constraint :backup_plans,
      "scenario IN ('weather', 'vendor', 'gift_delay', 'restaurant_unavailable', 'transportation', 'illness_cancellation')",
      name: "backup_plans_supported_scenario"
    add_check_constraint :backup_plans,
      "status IN ('generated', 'promoted', 'superseded')",
      name: "backup_plans_supported_status"
    add_check_constraint :backup_plans,
      "locale IN ('en', 'es')",
      name: "backup_plans_supported_locale"
    add_check_constraint :backup_plans,
      "context_fingerprint ~ '^[0-9a-f]{64}$'",
      name: "backup_plans_context_fingerprint_format"
    add_check_constraint :backup_options,
      "effort IN ('low', 'medium', 'high')",
      name: "backup_options_supported_effort"
    add_check_constraint :backup_options,
      "timing IN ('same_day', 'within_week', 'new_date')",
      name: "backup_options_supported_timing"
    add_check_constraint :backup_options,
      "cost_level IN ('lower', 'similar', 'higher', 'unknown')",
      name: "backup_options_supported_cost_level"
    add_check_constraint :backup_options,
      "relationship_fit IN ('strong', 'good', 'fair')",
      name: "backup_options_supported_relationship_fit"
    add_check_constraint :backup_options,
      "estimated_cost_cents IS NULL OR estimated_cost_cents >= 0",
      name: "backup_options_estimated_cost_nonnegative"
    add_check_constraint :backup_options,
      "position >= 0",
      name: "backup_options_position_nonnegative"
  end
end
