class AddSavedAtToSuggestionFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :suggestion_feedbacks, :saved_at, :datetime
  end
end
