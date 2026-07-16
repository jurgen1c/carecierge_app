class PrivacyVault::ChangeSuggestionUsage
  def self.call(actor:, item:, suggestion_usage:)
    new(actor:, item:, suggestion_usage:).call
  end

  def initialize(actor:, item:, suggestion_usage:)
    @actor = actor
    @item = item
    @suggestion_usage = suggestion_usage
  end

  def call
    relationship_profile = item.relationship_profile
    raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id

    relationship_profile.with_lock do
      item.lock!
      item.update!(suggestion_usage:)
      VaultAccessEvent.record!(
        event_type: "suggestion_usage_changed",
        user: actor,
        relationship_profile:,
        privacy_vault_item: item
      )
      item
    end
  end

  private

  attr_reader :actor, :item, :suggestion_usage
end
