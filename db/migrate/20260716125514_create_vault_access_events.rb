class CreateVaultAccessEvents < ActiveRecord::Migration[8.1]
  def up
    create_table :vault_access_events, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :relationship_profile, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.references :privacy_vault_item, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :vault_access_events, %i[user_id occurred_at]
    add_index :vault_access_events, %i[relationship_profile_id occurred_at]
    add_check_constraint :vault_access_events,
      "event_type IN ('unlock_failed', 'unlocked', 'locked', 'viewed', 'protected', 'restored', 'suggestion_usage_changed')",
      name: "vault_access_events_supported_event_type"
  end

  def down
    ensure_privacy_vault_empty!
    drop_table :vault_access_events
  end

  private

  def ensure_privacy_vault_empty!
    return unless table_exists?(:privacy_vault_items)
    return if select_value("SELECT 1 FROM privacy_vault_items LIMIT 1").blank?

    raise ActiveRecord::IrreversibleMigration,
      "Cannot drop vault support while protected items exist; restore them before rollback"
  end
end
