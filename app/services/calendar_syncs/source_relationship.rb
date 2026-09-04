module CalendarSyncs
  class SourceRelationship
    Resolution = Data.define(:profile, :profiles, :eligible)

    def self.resolve(source)
      profiles = profiles_for(source).compact.uniq(&:id)
      profile = profiles.one? ? profiles.first : nil
      Resolution.new(profile:, profiles:, eligible: profiles.length <= 1 && (profile.nil? || profile.kept?))
    end

    def self.profiles_for(source)
      case source
      when Booking
        [ source.event_plan&.relationship_profile ]
      when ImportantDate, EventPlan, Commitment
        [ source.relationship_profile ]
      when Reminder
        [
          source.relationship_profile,
          source.important_date&.relationship_profile,
          source.commitment&.relationship_profile,
          source.event_plan&.relationship_profile,
          source.plan_task&.event_plan&.relationship_profile,
          source.vendor_quote&.event_plan&.relationship_profile,
          source.booking&.event_plan&.relationship_profile
        ]
      else
        []
      end
    end
    private_class_method :profiles_for
  end
end
