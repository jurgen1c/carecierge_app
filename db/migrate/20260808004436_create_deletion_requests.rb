class CreateDeletionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :deletion_requests, id: :uuid do |t|
      t.references :user, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :request_kind, null: false
      t.string :status, null: false, default: "pending"
      t.string :account_digest, null: false
      t.string :subject_type
      t.uuid :subject_id
      t.datetime :requested_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :deletion_requests, [ :request_kind, :requested_at ]
    add_index :deletion_requests, [ :subject_type, :subject_id ]
    add_check_constraint :deletion_requests,
      "request_kind IN ('relationship_profile', 'privacy_vault_item', 'ai_generated', 'account')",
      name: "deletion_requests_supported_kind"
    add_check_constraint :deletion_requests,
      "status IN ('pending', 'completed', 'failed')",
      name: "deletion_requests_supported_status"
  end
end
