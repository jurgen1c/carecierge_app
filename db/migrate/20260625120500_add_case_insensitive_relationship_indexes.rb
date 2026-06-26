class AddCaseInsensitiveRelationshipIndexes < ActiveRecord::Migration[8.1]
  def up
    remove_index :relationship_types, [ :user_id, :name ]
    add_index :relationship_types, "user_id, lower(name)", unique: true, name: "index_relationship_types_on_user_id_and_lower_name"

    remove_index :relationship_tags, [ :relationship_profile_id, :name ]
    add_index :relationship_tags, "relationship_profile_id, lower(name)", unique: true, name: "index_relationship_tags_on_profile_id_and_lower_name"
  end

  def down
    remove_index :relationship_types, name: "index_relationship_types_on_user_id_and_lower_name"
    add_index :relationship_types, [ :user_id, :name ], unique: true

    remove_index :relationship_tags, name: "index_relationship_tags_on_profile_id_and_lower_name"
    add_index :relationship_tags, [ :relationship_profile_id, :name ], unique: true
  end
end
