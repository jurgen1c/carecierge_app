class CreateSharedRelationshipSpaces < ActiveRecord::Migration[8.1]
  def change
    create_table :shared_relationship_spaces, id: :uuid do |t|
      t.references :owner, type: :uuid, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :partner, type: :uuid, foreign_key: { to_table: :users, on_delete: :cascade }
      t.text :title, null: false
      t.text :invited_email, null: false
      t.datetime :invitation_expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :shared_relationship_spaces, :invited_email
    add_check_constraint :shared_relationship_spaces, "partner_id IS NULL OR partner_id <> owner_id", name: "shared_space_distinct_people"
    add_check_constraint :shared_relationship_spaces, "(partner_id IS NULL) = (accepted_at IS NULL)", name: "shared_space_acceptance_required"

    create_table :shared_items, id: :uuid do |t|
      t.references :shared_relationship_space, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :creator, type: :uuid, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :assignee, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :parent, type: :uuid, foreign_key: { to_table: :shared_items, on_delete: :nullify }
      t.string :kind, null: false
      t.text :title, null: false
      t.text :details
      t.string :editing, null: false, default: "creator"
      t.datetime :due_at
      t.string :time_zone, null: false, default: "UTC"
      t.datetime :completed_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :shared_items, [ :shared_relationship_space_id, :due_at ], name: "index_shared_items_on_space_and_due"
    add_check_constraint :shared_items, "kind IN ('plan', 'date', 'task', 'reminder', 'note')", name: "shared_item_kind"
    add_check_constraint :shared_items, "editing IN ('creator', 'participants')", name: "shared_item_editing"

    create_table :shared_reminder_subscriptions, id: :uuid do |t|
      t.references :shared_item, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :delivered_for
      t.timestamps
    end
    add_index :shared_reminder_subscriptions, [ :shared_item_id, :user_id ], unique: true, name: "index_shared_reminder_subscriptions_unique"
  end
end
