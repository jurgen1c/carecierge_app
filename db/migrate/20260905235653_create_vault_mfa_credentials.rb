class CreateVaultMfaCredentials < ActiveRecord::Migration[8.1]
  def up
    create_table :vault_mfa_credentials, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.text :totp_secret
      t.jsonb :recovery_code_digests, null: false, default: []
      t.datetime :enabled_at
      t.datetime :enrollment_expires_at
      t.string :enrollment_session_digest
      t.string :enrollment_password_fingerprint
      t.datetime :enrollment_verified_at
      t.bigint :last_totp_at
      t.integer :attempts, null: false, default: 0
      t.datetime :attempt_window_at

      t.timestamps
    end
  end
  def down
    if select_value("SELECT EXISTS (SELECT 1 FROM vault_mfa_credentials WHERE enabled_at IS NOT NULL)")
      raise ActiveRecord::IrreversibleMigration, "Disable vault MFA through verified owner flows before rollback"
    end

    drop_table :vault_mfa_credentials
  end
end
