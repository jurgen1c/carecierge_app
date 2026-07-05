class AddStructuredFieldsToRelationshipPreferences < ActiveRecord::Migration[8.1]
  def change
    change_table :relationship_preferences, bulk: true do |t|
      t.string :preference_type, null: false, default: "neutral"
      t.string :category, null: false, default: "general"
      t.string :confidence, null: false, default: "inferred"
      t.text :source_notes
      t.date :learned_on
    end

    add_index :relationship_preferences, [ :relationship_profile_id, :preference_type ]
    add_index :relationship_preferences, [ :relationship_profile_id, :category ]
    add_index :relationship_preferences, [ :relationship_profile_id, :confidence ]
  end
end
