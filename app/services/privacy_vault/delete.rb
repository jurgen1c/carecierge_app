module PrivacyVault
  class Delete
    def self.call(actor:, item:)
      DataDeletions::Perform.call(user: actor, request_kind: "privacy_vault_item", subject: item) do
        item.protectable.destroy!
      end
    end
  end
end
