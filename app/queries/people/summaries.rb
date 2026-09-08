module People
  class Summaries
    attr_reader :as_of

    def initialize(profiles:, user:, at: Time.current)
      @time_zone = OwnerLocalCalendar.time_zone_for(user:)
      @as_of = at.in_time_zone(@time_zone).to_date
      @last_interactions = Interaction.where(relationship_profile_id: profiles.map(&:id))
        .where(occurred_at: ..at).group(:relationship_profile_id).maximum(:occurred_at)
    end

    def last_interaction_on(profile)
      @last_interactions[profile.id]&.in_time_zone(@time_zone)&.to_date
    end

    def next_moment(profile)
      profile.upcoming_important_dates(as_of:, limit: 1).first unless profile.archived?
    end
  end
end
