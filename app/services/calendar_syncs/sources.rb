module CalendarSyncs
  class Sources
    REMINDER_BATCH_SIZE = 1_000

    def self.for(connection)
      user = connection.user
      profiles = user.relationship_profiles.kept.select(:id)
      sources = []
      sources.concat(ImportantDate.where(relationship_profile_id: profiles).order(:id)) if connection.syncs?(:important_dates)
      if connection.syncs?(:reminders)
        reminders = user.reminders.active
          .where(relationship_profile_id: nil).or(user.reminders.active.where(relationship_profile_id: profiles))
          .includes(
            :relationship_profile,
            { important_date: :relationship_profile },
            { commitment: :relationship_profile },
            { event_plan: :relationship_profile },
            { plan_task: { event_plan: :relationship_profile } },
            { vendor_quote: { event_plan: :relationship_profile } },
            { booking: { event_plan: :relationship_profile } }
          )
        reminders.find_each(batch_size: REMINDER_BATCH_SIZE) do |reminder|
          sources << reminder if CalendarSyncs::SourceRelationship.resolve(reminder).eligible
        end
      end
      if connection.syncs?(:event_plans)
        sources.concat(user.event_plans.visible.for_active_relationships.where.not(starts_on: nil).order(:id))
      end
      if connection.syncs?(:bookings)
        sources.concat(
          user.bookings
            .where(event_plan_id: user.event_plans.for_active_relationships.select(:id))
            .where.not(status: %w[cancelled completed])
            .order(:id)
        )
      end
      if connection.syncs?(:commitments)
        sources.concat(Commitment.where(relationship_profile_id: profiles, status: "open").where.not(due_on: nil).order(:id))
      end
      sources
    end
  end
end
