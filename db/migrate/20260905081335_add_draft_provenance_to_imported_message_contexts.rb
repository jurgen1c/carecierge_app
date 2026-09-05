class AddDraftProvenanceToImportedMessageContexts < ActiveRecord::Migration[8.1]
  def change
    add_column :imported_message_contexts, :reply_ai_generated, :boolean, null: false, default: false
  end
end
