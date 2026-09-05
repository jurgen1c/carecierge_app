class AddRelationshipModeToGiftRecommendations < ActiveRecord::Migration[8.1]
  def change
    add_column :gift_recommendations, :relationship_mode, :string, null: false, default: "personal"
  end
end
