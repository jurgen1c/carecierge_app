class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :actor, null: true, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :actor_kind, null: false
      t.string :action, null: false
      t.string :source, null: false
      t.references :target, polymorphic: true, null: true, type: :uuid, index: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :audit_events, [ :user_id, :occurred_at ], order: { occurred_at: :desc }
    add_index :audit_events,
      [ :occurred_at, :created_at, :id ],
      order: { occurred_at: :desc, created_at: :desc, id: :desc },
      name: "index_audit_events_on_global_order"
    add_index :audit_events, [ :action, :occurred_at ], order: { occurred_at: :desc }
    add_index :audit_events, [ :source, :occurred_at ], order: { occurred_at: :desc }
    add_index :audit_events, [ :target_type, :target_id ]
    add_check_constraint :audit_events, "jsonb_typeof(metadata) = 'object'", name: "audit_events_metadata_is_object"
  end
end
