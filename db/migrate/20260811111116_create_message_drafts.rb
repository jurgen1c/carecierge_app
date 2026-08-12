class CreateMessageDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :message_drafts, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :relationship_profile,
        null: false,
        foreign_key: { on_delete: :cascade },
        type: :uuid,
        index: { unique: true }
      t.string :draft_type, null: false
      t.string :tone, null: false

      t.timestamps
    end

    create_table :draft_revisions, id: :uuid do |t|
      t.references :message_draft, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.integer :position, null: false
      t.string :origin, null: false
      t.text :content, null: false
      t.jsonb :context_categories, null: false, default: []

      t.timestamps
    end

    add_index :draft_revisions, %i[message_draft_id position], unique: true
    add_check_constraint :draft_revisions, "position > 0", name: "draft_revisions_position_positive"
  end
end
