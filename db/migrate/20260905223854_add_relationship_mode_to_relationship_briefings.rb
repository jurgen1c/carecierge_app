class AddRelationshipModeToRelationshipBriefings < ActiveRecord::Migration[8.1]
  def change
    add_column :relationship_briefings, :relationship_mode, :string, null: false, default: "personal"
    remove_index :relationship_briefings, :relationship_profile_id, name: "index_relationship_briefings_on_one_generated_per_profile", unique: true, where: "status = 'generated'"
    add_index :relationship_briefings, [ :relationship_profile_id, :relationship_mode ], unique: true, where: "status = 'generated'", name: "index_relationship_briefings_on_generated_mode"
  end
end
