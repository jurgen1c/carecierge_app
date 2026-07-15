class CreateInteractions < ActiveRecord::Migration[8.1]
  def change
    create_table :interactions, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :interaction_type, null: false
      t.string :origin, null: false, default: "manual"
      t.datetime :occurred_at, null: false
      t.text :notes
      t.references :source, polymorphic: true, null: true, type: :uuid, index: false

      t.timestamps
    end


    add_index :interactions, [ :relationship_profile_id, :occurred_at, :id ], order: { occurred_at: :desc }
    add_index :interactions,
      [ :source_type, :source_id ],
      unique: true,
      where: "source_id IS NOT NULL",
      name: "index_interactions_on_unique_source"
    add_check_constraint :interactions,
      "interaction_type IN ('call', 'message', 'in_person', 'video', 'other', 'conversation_recap', 'mood_note')",
      name: "interactions_supported_type"
    add_check_constraint :interactions,
      "origin IN ('manual', 'derived')",
      name: "interactions_supported_origin"
    add_check_constraint :interactions,
      "(origin = 'manual' AND source_id IS NULL AND source_type IS NULL) OR (origin = 'derived' AND source_id IS NOT NULL AND source_type IS NOT NULL)",
      name: "interactions_origin_matches_source"
  end
end
