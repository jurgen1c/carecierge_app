module Concierge
  class GiftSources
    TYPES = %w[GiftPurchasePlan GiftBox GiftBoxItem].freeze

    def self.find(reference, user:, turn:)
      profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"])
      return unless profile && turn
      return if profile.professional? && !profile.professional_gifts_allowed?

      case reference["record_type"]
      when "GiftPurchasePlan"
        record = GiftPurchasePlan.joins(:gift).where(gifts: { relationship_profile_id: profile.id }).find_by(id: reference["id"])
        record if record && Sources.scope(profile:, association: :gifts, turn:).exists?(id: record.gift_id)
      when "GiftBox"
        Sources.scope(profile:, association: :gift_boxes, turn:).find_by(id: reference["id"])
      when "GiftBoxItem"
        GiftBoxItem.where(gift_box_id: Sources.scope(profile:, association: :gift_boxes, turn:).select(:id)).find_by(id: reference["id"])
      end
    end
  end
end
