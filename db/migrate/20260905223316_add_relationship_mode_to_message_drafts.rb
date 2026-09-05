class AddRelationshipModeToMessageDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :message_drafts, :relationship_mode, :string, null: false, default: "personal"
  end
end
