class CreateRelationshipTags < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:relationship_tags)

    create_table :relationship_tags, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false

      t.timestamps
    end

    add_index :relationship_tags,
              "relationship_profile_id, lower(name)",
              unique: true,
              name: "index_relationship_tags_on_profile_id_and_lower_name"
  end
end
