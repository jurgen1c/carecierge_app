class AddFamilyCoordination < ActiveRecord::Migration[8.1]
  def change
    add_column :shared_relationship_spaces, :mode, :string, null: false, default: "couple"
    change_column_null :shared_relationship_spaces, :invited_email, true
    change_column_null :shared_relationship_spaces, :invitation_expires_at, true
    add_check_constraint :shared_relationship_spaces, "mode IN ('couple', 'family')", name: "shared_space_mode"
    add_column :shared_items, :category, :string, null: false, default: "general"

    create_table :family_memberships, id: :uuid do |t|
      t.references :shared_relationship_space, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :invited_email, null: false
      t.string :relationship_type, null: false
      t.datetime :invitation_expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :family_memberships, [ :shared_relationship_space_id, :invited_email ], unique: true, name: "index_family_memberships_on_space_email"
    add_index :family_memberships, [ :shared_relationship_space_id, :user_id ], unique: true, name: "index_family_memberships_on_space_user"
    add_index :family_memberships, :invited_email
    add_check_constraint :family_memberships, "(user_id IS NULL) = (accepted_at IS NULL)", name: "family_membership_acceptance_required"

    create_table :family_responses, id: :uuid do |t|
      t.references :shared_item, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :attendance, null: false
      t.timestamps
    end
    add_index :family_responses, [ :shared_item_id, :user_id ], unique: true
    add_check_constraint :family_responses, "attendance IN ('yes', 'maybe', 'no')", name: "family_response_attendance"
  end
end
