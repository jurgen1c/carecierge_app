module PrivacyVaultsHelper
  def privacy_vault_candidate_label(record)
    case record
    when MemoryRecord
      record.title
    when RelationshipNote
      record.category.presence || t("privacy_vaults.item_types.private_note")
    when RelationshipFieldValue
      record.display_label
    end
  end
end
