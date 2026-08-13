class AddResponsePreferencesToMessageDrafts < ActiveRecord::Migration[8.1]
  def change
    add_column :message_drafts, :situation, :text, null: false, default: ""
    add_column :message_drafts, :response_length, :string, null: false, default: "medium"
    add_column :message_drafts, :formality, :string, null: false, default: "balanced"

    add_check_constraint :message_drafts,
      "char_length(situation) <= 4000",
      name: "message_drafts_situation_length"
    add_check_constraint :message_drafts,
      "response_length IN ('short', 'medium', 'long')",
      name: "message_drafts_response_length"
    add_check_constraint :message_drafts,
      "formality IN ('casual', 'balanced', 'formal')",
      name: "message_drafts_formality"
  end
end
