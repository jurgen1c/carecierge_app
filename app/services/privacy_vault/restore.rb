class PrivacyVault::Restore
  def self.call(actor:, item:)
    new(actor:, item:).call
  end

  def initialize(actor:, item:)
    @actor = actor
    @item = item
  end

  def call
    relationship_profile = item.relationship_profile
    raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id

    relationship_profile.with_lock do
      item.lock!
      item.protectable.lock!
      PrivacyVault::Payload.new(item.protectable).restore!(payload: item.payload)
      VaultAccessEvent.record!(
        event_type: "restored",
        user: actor,
        relationship_profile:,
        privacy_vault_item: item
      )
      item.destroy!
    end
  end

  private

  attr_reader :actor, :item
end
