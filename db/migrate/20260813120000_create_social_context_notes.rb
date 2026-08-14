class CreateSocialContextNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :social_context_notes, id: :uuid do |t|
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.boolean :allow_suggestions, null: false, default: false
      t.text :interpretation
      t.string :interpretation_status, null: false, default: "not_requested"
      t.jsonb :suggested_uses, null: false, default: []
      t.datetime :analyzed_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :social_context_notes, [ :relationship_profile_id, :created_at ]
    add_index :social_context_notes, [ :relationship_profile_id, :allow_suggestions ],
      name: "index_social_context_notes_on_profile_and_suggestion_usage"
    add_check_constraint :social_context_notes,
      "interpretation_status IN ('not_requested', 'draft', 'approved')",
      name: "social_context_notes_interpretation_status"
    add_check_constraint :social_context_notes,
      "jsonb_typeof(suggested_uses) = 'array'",
      name: "social_context_notes_suggested_uses_array"
  end
end
