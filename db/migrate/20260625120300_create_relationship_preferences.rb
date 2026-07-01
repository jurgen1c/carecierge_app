class CreateRelationshipPreferences < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:relationship_preferences)

    create_table :relationship_preferences, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :key, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :relationship_preferences,
              "relationship_profile_id, lower(key)",
              unique: true,
              name: "idx_relationship_preferences_on_profile_and_lower_key"
  end
end
