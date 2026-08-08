class CreateSuggestionFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :suggestion_feedbacks, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :fingerprint, null: false
      t.string :feedback
      t.datetime :dismissed_at
      t.datetime :acted_at

      t.timestamps
    end

    add_index :suggestion_feedbacks, %i[user_id fingerprint], unique: true
    add_index :suggestion_feedbacks, %i[relationship_profile_id dismissed_at]
    add_check_constraint :suggestion_feedbacks,
      "feedback IS NULL OR feedback IN ('helpful', 'not_for_me')",
      name: "suggestion_feedbacks_supported_feedback"
  end
end
