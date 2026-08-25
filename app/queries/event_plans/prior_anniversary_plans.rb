module EventPlans
  class PriorAnniversaryPlans
    MAX_PER_RELATIONSHIP = 8

    def self.call(user:, relationship_profile: nil, excluding: nil)
      scope = user.event_plans
        .joins(:relationship_profile)
        .merge(user.relationship_profiles.active)
        .where(occasion_type: "anniversary", status: %w[completed archived])
      scope = scope.where.not(id: excluding.id) if excluding&.persisted?

      if relationship_profile
        return scope.where(relationship_profile:)
          .reorder(Arel.sql("starts_on DESC NULLS LAST"), created_at: :desc, id: :desc)
          .limit(MAX_PER_RELATIONSHIP)
          .to_a
      end

      ranked = scope.select(
        "event_plans.*",
        Arel.sql(<<~SQL.squish)
          ROW_NUMBER() OVER (
            PARTITION BY event_plans.relationship_profile_id
            ORDER BY event_plans.starts_on DESC NULLS LAST, event_plans.created_at DESC, event_plans.id DESC
          ) AS prior_anniversary_rank
        SQL
      )
      EventPlan.from(ranked, :event_plans)
        .where("prior_anniversary_rank <= ?", MAX_PER_RELATIONSHIP)
        .reorder(:relationship_profile_id, Arel.sql("prior_anniversary_rank ASC"))
        .to_a
    end
  end
end
