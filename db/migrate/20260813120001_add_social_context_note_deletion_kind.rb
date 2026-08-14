class AddSocialContextNoteDeletionKind < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :deletion_requests, name: "deletion_requests_supported_kind"
    add_check_constraint :deletion_requests,
      "request_kind IN ('relationship_profile', 'privacy_vault_item', 'social_context_note', 'ai_generated', 'account')",
      name: "deletion_requests_supported_kind"
  end

  def down
    if DeletionRequest.where(request_kind: "social_context_note").exists?
      raise ActiveRecord::IrreversibleMigration, "social context deletion evidence remains"
    end

    remove_check_constraint :deletion_requests, name: "deletion_requests_supported_kind"
    add_check_constraint :deletion_requests,
      "request_kind IN ('relationship_profile', 'privacy_vault_item', 'ai_generated', 'account')",
      name: "deletion_requests_supported_kind"
  end
end
