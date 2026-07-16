module NotificationPreferences
  class Save
    MODES = %w[inherit muted].freeze
    QUIET_HOUR_ATTRIBUTES = %w[
      quiet_hours_enabled
      quiet_hours_start
      quiet_hours_end
      time_zone
      high_priority_alerts_enabled
    ].freeze

    def self.call(preference, attributes:, relationship_modes: {})
      new(preference, attributes:, relationship_modes:).call
    end

    def initialize(preference, attributes:, relationship_modes:)
      @preference = preference
      @attributes = attributes
      @relationship_modes = relationship_modes.to_h
    end

    def call
      NotificationPreference.transaction do
        preference.update!(attributes_with_time_zone_intent)
        sync_relationship_modes!
        release_deferred_reminders!
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end

    private

    attr_reader :preference, :attributes, :relationship_modes

    def attributes_with_time_zone_intent
      return attributes unless attributes.key?(:time_zone) || attributes.key?("time_zone")

      attributes.merge(time_zone_configured: true)
    end

    def sync_relationship_modes!
      relationship_modes.each_value { |mode| validate_mode!(mode) }

      profile_ids = relationship_modes.keys
      profiles_by_id = preference.user.relationship_profiles
        .find(profile_ids)
        .index_by { |profile| profile.id.to_s }
      overrides_by_profile_id = preference.relationship_notification_preferences
        .where(relationship_profile_id: profile_ids)
        .index_by { |override| override.relationship_profile_id.to_s }

      relationship_modes.each do |profile_id, mode|
        profile = profiles_by_id.fetch(profile_id.to_s)
        override = overrides_by_profile_id[profile_id.to_s]
        override&.relationship_profile = profile

        if mode == "inherit"
          override&.destroy!
        else
          (override || preference.relationship_notification_preferences.build(relationship_profile: profile)).update!(mode:)
        end
      end
    end

    def validate_mode!(mode)
      return if MODES.include?(mode)

      preference.errors.add(:base, :invalid_relationship_mode)
      raise ActiveRecord::RecordInvalid, preference
    end

    def release_deferred_reminders!
      return if (preference.saved_changes.keys & QUIET_HOUR_ATTRIBUTES).empty?

      now = Time.current
      preference.user.reminders
        .active
        .where(snoozed_until: nil, scheduled_at: ..now)
        .where.not(next_delivery_at: nil)
        .where("next_delivery_at > ?", now)
        .update_all(next_delivery_at: Arel.sql("scheduled_at"), updated_at: now)
    end
  end
end
