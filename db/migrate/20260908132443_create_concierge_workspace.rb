class CreateConciergeWorkspace < ActiveRecord::Migration[8.1]
  def change
    create_table :concierge_conversations, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.references :relationship_profile, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :title
      t.timestamps
    end
    add_index :concierge_conversations, [ :user_id, :updated_at, :id ], name: "idx_concierge_conversations_history"

    create_table :concierge_turns, id: :uuid do |t|
      t.references :conversation, null: false, type: :uuid, foreign_key: { to_table: :concierge_conversations, on_delete: :cascade }, index: false
      t.string :request_key, null: false, limit: 64
      t.text :content, null: false
      t.text :response
      t.text :context
      t.string :locale, null: false, default: "en"
      t.string :state, null: false, default: "queued"
      t.uuid :run_token
      t.datetime :started_at
      t.datetime :finished_at
      t.string :error_code
      t.integer :attempts, null: false, default: 0
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.timestamps
    end
    add_index :concierge_turns, [ :conversation_id, :request_key ], unique: true
    add_index :concierge_turns, [ :conversation_id, :created_at, :id ], name: "idx_concierge_turns_history"
    add_check_constraint :concierge_turns, "locale IN ('en', 'es')", name: "concierge_turns_locale"
    add_check_constraint :concierge_turns, "state IN ('queued', 'running', 'completed', 'failed')", name: "concierge_turns_state"

    create_table :concierge_actions, id: :uuid do |t|
      t.references :turn, null: false, type: :uuid, foreign_key: { to_table: :concierge_turns, on_delete: :cascade }, index: false
      t.string :name, null: false
      t.string :fingerprint, null: false, limit: 64
      t.text :arguments
      t.text :result
      t.text :precondition
      t.string :state, null: false, default: "pending"
      t.datetime :decided_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :concierge_actions, [ :turn_id, :fingerprint ], unique: true
    add_check_constraint :concierge_actions, "state IN ('pending', 'awaiting_approval', 'approved', 'succeeded', 'failed', 'rejected')", name: "concierge_actions_state"
  end
end
