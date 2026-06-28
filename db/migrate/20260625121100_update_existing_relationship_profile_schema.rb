class UpdateExistingRelationshipProfileSchema < ActiveRecord::Migration[8.1]
  def up
    add_column :relationship_profiles, :relationship_type_name, :string unless column_exists?(:relationship_profiles, :relationship_type_name)
    add_column :relationship_profiles, :discarded_at, :datetime unless column_exists?(:relationship_profiles, :discarded_at)
    add_column :relationship_profiles, :slug, :string unless column_exists?(:relationship_profiles, :slug)

    if column_exists?(:relationship_profiles, :relationship_type_id) && table_exists?(:relationship_types)
      execute <<~SQL.squish
        UPDATE relationship_profiles
        SET relationship_type_name = relationship_types.name
        FROM relationship_types
        WHERE relationship_profiles.relationship_type_id = relationship_types.id
          AND relationship_profiles.relationship_type_name IS NULL
      SQL
    end

    if column_exists?(:relationship_profiles, :archived_at) && column_exists?(:relationship_profiles, :discarded_at)
      execute <<~SQL.squish
        UPDATE relationship_profiles
        SET discarded_at = archived_at
        WHERE discarded_at IS NULL
          AND archived_at IS NOT NULL
      SQL
    end

    remove_foreign_key :relationship_profiles, name: "fk_relationship_profiles_type_owner" if foreign_key_exists?(:relationship_profiles, name: "fk_relationship_profiles_type_owner")
    remove_foreign_key :relationship_profiles, :relationship_types if foreign_key_exists?(:relationship_profiles, :relationship_types)
    remove_index :relationship_profiles, :relationship_type_id if index_exists?(:relationship_profiles, :relationship_type_id)
    remove_index :relationship_profiles, [ :user_id, :archived_at ] if index_exists?(:relationship_profiles, [ :user_id, :archived_at ])

    remove_column :relationship_profiles, :relationship_type_id if column_exists?(:relationship_profiles, :relationship_type_id)
    remove_column :relationship_profiles, :structured_preferences if column_exists?(:relationship_profiles, :structured_preferences)
    remove_column :relationship_profiles, :archived_at if column_exists?(:relationship_profiles, :archived_at)

    add_index :relationship_profiles, :relationship_type_name unless index_exists?(:relationship_profiles, :relationship_type_name)
    add_index :relationship_profiles, :slug, unique: true unless index_exists?(:relationship_profiles, :slug)
    add_index :relationship_profiles, [ :user_id, :discarded_at ] unless index_exists?(:relationship_profiles, [ :user_id, :discarded_at ])

    drop_table :relationship_types if table_exists?(:relationship_types)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
