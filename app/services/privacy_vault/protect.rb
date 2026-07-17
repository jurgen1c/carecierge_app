class PrivacyVault::Protect
  def self.call(actor:, protectable:)
    new(actor:, protectable:).call
  end

  def initialize(actor:, protectable:)
    @actor = actor
    @protectable = protectable
  end

  def call
    relationship_profile = protectable.relationship_profile
    raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id

    relationship_profile.with_lock do
      protectable.lock!
      reject_embedded_files!
      payload = PrivacyVault::Payload.new(protectable)
      item = relationship_profile.privacy_vault_items.create!(
        protectable:,
        payload: payload.dump,
        suggestion_usage: "excluded",
        protected_at: Time.current
      )
      payload.redact!(item:)
      VaultAccessEvent.record!(
        event_type: "protected",
        user: actor,
        relationship_profile:,
        privacy_vault_item: item
      )
      item
    end
  end

  private

  attr_reader :actor, :protectable

  def reject_embedded_files!
    return unless protectable.is_a?(RelationshipNote) && protectable.body.embeds.attached?

    protectable.errors.add(:base, :vault_embeds_not_supported)
    raise ActiveRecord::RecordInvalid, protectable
  end
end
