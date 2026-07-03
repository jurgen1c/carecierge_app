class AddCascadeToRelationshipAssignmentForeignKeys < ActiveRecord::Migration[8.1]
  def up
    replace_foreign_key :relationship_taggings, :relationship_profiles, on_delete: :cascade
    replace_foreign_key :relationship_taggings, :relationship_tags, on_delete: :cascade
    replace_foreign_key :relationship_group_memberships, :relationship_profiles, on_delete: :cascade
    replace_foreign_key :relationship_group_memberships, :relationship_groups, on_delete: :cascade
  end

  def down
    replace_foreign_key :relationship_taggings, :relationship_profiles
    replace_foreign_key :relationship_taggings, :relationship_tags
    replace_foreign_key :relationship_group_memberships, :relationship_profiles
    replace_foreign_key :relationship_group_memberships, :relationship_groups
  end

  private

  def replace_foreign_key(from_table, to_table, on_delete: nil)
    remove_foreign_key from_table, to_table if foreign_key_exists?(from_table, to_table)

    options = {}
    options[:on_delete] = on_delete if on_delete.present?

    add_foreign_key from_table, to_table, **options
  end
end
