class CreateConversationRecaps < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_recaps, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :occurred_at, null: false
      t.string :capture_source, null: false, default: "typed"
      t.text :transcript
      t.string :extraction_status, null: false, default: "not_requested"
      t.datetime :extraction_requested_at
      t.datetime :extraction_approved_at

      t.timestamps
    end

    add_index :conversation_recaps, [ :relationship_profile_id, :occurred_at ]
    add_index :conversation_recaps, [ :relationship_profile_id, :capture_source ]
    add_index :conversation_recaps, [ :relationship_profile_id, :extraction_status ]
  end
end
