class AddProfileAttributesToRelationshipProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :relationship_profiles, :profile_attributes, :jsonb, null: false, default: {}
  end
end
