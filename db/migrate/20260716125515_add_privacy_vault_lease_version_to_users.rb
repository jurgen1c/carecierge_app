class AddPrivacyVaultLeaseVersionToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :privacy_vault_lease_version, :integer, default: 0, null: false
  end

  def down
    ensure_privacy_vault_empty!
    remove_column :users, :privacy_vault_lease_version
  end

  private

  def ensure_privacy_vault_empty!
    return unless table_exists?(:privacy_vault_items)
    return if select_value("SELECT 1 FROM privacy_vault_items LIMIT 1").blank?

    raise ActiveRecord::IrreversibleMigration,
      "Cannot drop vault support while protected items exist; restore them before rollback"
  end
end
