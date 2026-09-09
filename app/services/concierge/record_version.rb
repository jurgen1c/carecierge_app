require "digest"

module Concierge
  class RecordVersion
    # Generation fences are concurrency metadata, not relationship facts. A
    # failed generation must not invalidate its own still-current approval.
    PROFILE_FENCES = %w[message_draft_generation_version briefing_generation_version gift_recommendation_generation_version].freeze

    RECAP_EXTRACTION_FIELDS = %w[extraction_status extraction_requested_at extraction_started_at extraction_completed_at extraction_approved_at extraction_error_code].freeze

    def self.for(record)
      # Rich-text autosave can defer a parent touch until transaction commit.
      # Hash the actual content instead of a timestamp that can change afterward.
      attributes = record.attributes.except("updated_at")
      attributes = attributes.except(*PROFILE_FENCES, "lock_version") if record.is_a?(RelationshipProfile)
      attributes = attributes.except("generation_version", "lock_version") if record.is_a?(EventPlan)
      case record
      when MemoryRecord
        attributes["stale"] = record.stale_after.present? &&
          record.stale_after < OwnerLocalCalendar.date_for(user: record.relationship_profile.user)
      when ConversationRecap
        attributes = attributes.except(*RECAP_EXTRACTION_FIELDS)
      when MessageDraft
        attributes["revision_ids"] = record.draft_revisions.reorder(:id).pluck(:id)
      when ContactCadence
        attributes["last_interaction_at"] = record.relationship_profile.interactions.maximum(:occurred_at) unless record.relationship_profile.professional?
      when Interaction
        attributes["display_notes"] = record.display_notes
      when ApprovalRequest
        attributes["subject_version"] = self.for(record.subject)
      when RelationshipNote, SocialContextNote
        attributes["rich_text_body"] = record.rich_text_body&.body&.to_html
      when GiftBox
        attributes["items"] = record.items.sort_by(&:id).map { |item| item.attributes.except("updated_at") }
      when GiftPurchasePlan
        attributes["gift_name"] = record.gift.name
      when VendorOption, VendorQuote
        attributes["vendor_name"] = record.vendor.name
      end
      digest(attributes)
    end

    def self.digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def self.canonical(value)
      case value
      when Hash then value.stringify_keys.sort.to_h.transform_values { |nested| canonical(nested) }
      when Array then value.map { |nested| canonical(nested) }
      when Time, DateTime, ActiveSupport::TimeWithZone then value.to_time.utc.iso8601(6)
      when Date then value.iso8601
      else value.as_json
      end
    end
    private_class_method :canonical
  end
end
