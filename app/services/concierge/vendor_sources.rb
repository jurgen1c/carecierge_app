module Concierge
  class VendorSources
    TYPES = %w[Vendor VendorShortlist VendorOption VendorQuote Booking].freeze

    def self.find(reference, user:, turn:)
      case reference["record_type"]
      when "Vendor"
        profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"])
        return if turn&.context&.fetch("relationship_mode", nil) == "professional" && !profile&.professional?
        vendor_scope(profile:, user:).find_by(id: reference["id"])
      when "VendorShortlist"
        record = user.vendor_shortlists.find_by(id: reference["id"])
        record if shortlist_visible?(record, user:, turn:)
      when "VendorOption"
        record = VendorOption.joins(:vendor_shortlist).where(vendor_shortlists: { user_id: user.id }).find_by(id: reference["id"])
        record if option_visible?(record, user:, turn:)
      when "VendorQuote", "Booking"
        relation = reference["record_type"] == "VendorQuote" ? user.vendor_quotes : user.bookings
        record = relation.find_by(id: reference["id"])
        return unless record && turn && OccasionSources.plan_visible?(record.event_plan, turn:)
        return if record.is_a?(VendorQuote) && !vendor_scope(profile: record.event_plan.relationship_profile, user:).exists?(id: record.vendor_id)
        record
      end
    end

    def self.vendor_scope(profile:, user:)
      profile&.professional? ? profile.work_context.selected("vendors") : user.vendors
    end

    def self.shortlist_visible?(record, user:, turn:)
      return false unless record && record.user_id == user.id && turn
      profile = record.relationship_profile
      return false if profile.archived? || profile.user_id != user.id
      return false if profile.professional? && !profile.work_context.selected("vendor_shortlists").exists?(id: record.id)
      !record.event_plan || OccasionSources.plan_visible?(record.event_plan, turn:)
    end

    def self.option_visible?(record, user:, turn:)
      record && shortlist_visible?(record.vendor_shortlist, user:, turn:) &&
        vendor_scope(profile: record.vendor_shortlist.relationship_profile, user:).exists?(id: record.vendor_id)
    end
  end
end
