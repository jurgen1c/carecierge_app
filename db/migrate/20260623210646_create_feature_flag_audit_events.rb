class CreateFeatureFlagAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flag_audit_events, id: :uuid do |t|
      t.references :feature_flag, null: false, foreign_key: true, type: :uuid
      t.references :actor, foreign_key: { to_table: :users }, type: :uuid
      t.string :action, null: false
      t.jsonb :details, null: false, default: {}

      t.timestamps
    end

    add_index :feature_flag_audit_events, :action
  end
end
