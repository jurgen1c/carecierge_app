class CreateApprovalQueue < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_requests, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :subject, polymorphic: true, type: :uuid, null: false
      t.string :kind, null: false
      t.string :action_key, null: false
      t.string :status, null: false, default: "pending"
      t.string :risk_level, null: false
      t.string :confidence
      t.datetime :subject_updated_at, null: false
      t.datetime :deferred_until
      t.datetime :decided_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :approval_requests, %i[user_id status created_at]
    add_index :approval_requests,
      %i[user_id subject_type subject_id action_key],
      unique: true,
      where: "status IN ('pending', 'deferred')",
      name: "idx_approval_requests_one_open_action"
    add_check_constraint :approval_requests,
      "status IN ('pending', 'deferred', 'approved', 'rejected', 'dismissed', 'superseded')",
      name: "approval_requests_supported_status"
    add_check_constraint :approval_requests,
      "risk_level IN ('low', 'medium', 'high', 'sensitive')",
      name: "approval_requests_supported_risk"
    add_check_constraint :approval_requests,
      "confidence IS NULL OR confidence IN ('confirmed', 'high', 'medium', 'low', 'inferred')",
      name: "approval_requests_supported_confidence"

    create_table :approval_decisions, id: :uuid do |t|
      t.references :approval_request, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :decision, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :approval_decisions, %i[approval_request_id occurred_at]
    add_check_constraint :approval_decisions,
      "decision IN ('approve', 'reject', 'edit', 'defer', 'dismiss')",
      name: "approval_decisions_supported_decision"
  end
end
