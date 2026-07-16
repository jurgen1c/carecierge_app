class CreatePrivacyVaultItems < ActiveRecord::Migration[8.1]
  def up
    create_table :privacy_vault_items, id: :uuid do |t|
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :protectable, null: false, polymorphic: true, type: :uuid, index: false
      t.text :payload, null: false
      t.string :suggestion_usage, null: false, default: "excluded"
      t.datetime :protected_at, null: false
      t.timestamps
    end

    add_index :privacy_vault_items,
      %i[protectable_type protectable_id],
      unique: true,
      name: "index_privacy_vault_items_on_protectable"
    add_index :privacy_vault_items, %i[relationship_profile_id protected_at]
    add_check_constraint :privacy_vault_items,
      "protectable_type IN ('MemoryRecord', 'RelationshipFieldValue', 'RelationshipNote')",
      name: "privacy_vault_items_supported_protectable_type"
    add_check_constraint :privacy_vault_items,
      "suggestion_usage IN ('excluded', 'allowed')",
      name: "privacy_vault_items_supported_suggestion_usage"
  end

  def down
    if table_exists?(:privacy_vault_items) && select_value("SELECT 1 FROM privacy_vault_items LIMIT 1").present?
      raise ActiveRecord::IrreversibleMigration,
        "Cannot drop privacy_vault_items while protected items exist; restore them before rollback"
    end

    drop_table :privacy_vault_items
  end
end
