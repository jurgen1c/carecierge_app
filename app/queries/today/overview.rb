module Today
  class Overview
    PREVIEW_LIMIT = 4
    CHECK_IN_AT_SQL = <<~SQL.squish.freeze
      COALESCE(
        (SELECT MAX(interactions.occurred_at) FROM interactions
         WHERE interactions.relationship_profile_id = contact_cadences.relationship_profile_id),
        contact_cadences.created_at
      ) + contact_cadences.interval_days * INTERVAL '1 day'
    SQL

    attr_reader :user, :as_of

    def initialize(user:, as_of: Time.current)
      @user = user
      @as_of = as_of
    end

    def local_now
      as_of.in_time_zone(OwnerLocalCalendar.time_zone_for(user:))
    end

    def feed
      @feed ||= DailyFeed::ForUser.call(user:, as_of:)
    end

    def profile_count
      @profile_count ||= user.relationship_profiles.kept.count
    end

    def plans
      @plans ||= plan_scope.includes(:relationship_profile).limit(PREVIEW_LIMIT).to_a
    end

    def plan_count
      @plan_count ||= plan_scope.count
    end

    def check_ins
      @check_ins ||= begin
        records = ContactCadence.where(relationship_profile_id: profile_ids)
          .where("#{CHECK_IN_AT_SQL} <= ?", as_of)
          .order(Arel.sql(CHECK_IN_AT_SQL), :id)
          .includes(:relationship_profile).limit(PREVIEW_LIMIT).to_a
        last_interactions = Interaction.where(relationship_profile_id: records.map(&:relationship_profile_id))
          .group(:relationship_profile_id).maximum(:occurred_at)
        records.each { |cadence| cadence.preload_last_interaction_at(last_interactions[cadence.relationship_profile_id]) }
      end
    end

    def review_count
      @review_count ||= begin
        pending = user.approval_requests.pending_review
        extracted = ExtractedMemory.where(relationship_profile_id: profile_ids, status: "pending").select(:id)
        memories = MemoryRecord.where(relationship_profile_id: profile_ids, high_impact_automation_approved_at: nil)
          .where.not(status: "archived").unprotected
          .where("source = 'ai_inferred' OR confidence IN ('low', 'inferred')").select(:id)
        pending.where(subject_type: "ExtractedMemory", subject_id: extracted, action_key: "review_extracted_memory")
          .or(pending.where(subject_type: "MemoryRecord", subject_id: memories, action_key: "approve_high_impact_memory"))
          .count
      end
    end

    private

    def profile_ids
      user.relationship_profiles.kept.select(:id)
    end

    def plan_scope
      user.event_plans.where(relationship_profile_id: profile_ids, status: "active",
        starts_on: local_now.to_date..(local_now.to_date + 30.days)).ordered
    end
  end
end
