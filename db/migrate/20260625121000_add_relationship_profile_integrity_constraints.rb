class AddRelationshipProfileIntegrityConstraints < ActiveRecord::Migration[8.1]
  def change
    remove_index :contact_methods, [ :relationship_profile_id, :kind ]
    add_index :contact_methods, [ :relationship_profile_id, :kind ], unique: true

    add_index :relationship_types, [ :id, :user_id ], unique: true
    add_foreign_key :relationship_profiles,
                    :relationship_types,
                    column: [ :relationship_type_id, :user_id ],
                    primary_key: [ :id, :user_id ],
                    name: "fk_relationship_profiles_type_owner"
  end
end
