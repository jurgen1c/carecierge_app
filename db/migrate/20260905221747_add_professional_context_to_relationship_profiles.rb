class AddProfessionalContextToRelationshipProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :relationship_profiles, :relationship_mode, :string, null: false, default: "personal"
    add_column :relationship_profiles, :professional_context, :text
    add_check_constraint :relationship_profiles, "relationship_mode IN ('personal', 'professional')", name: "relationship_profiles_mode"
  end
end
