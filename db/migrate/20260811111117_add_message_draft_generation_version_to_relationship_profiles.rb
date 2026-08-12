class AddMessageDraftGenerationVersionToRelationshipProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :relationship_profiles, :message_draft_generation_version, :bigint, null: false, default: 0
  end
end
