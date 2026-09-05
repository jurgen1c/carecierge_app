module DataDeletions
  class DeleteAiData
    def self.call(user:)
      user.with_lock("FOR NO KEY UPDATE") do
        user.messaging_connection&.imported_message_contexts&.where(reply_ai_generated: true)&.find_each do |context|
          context.update!(reply_draft: nil, reply_ai_generated: false)
        end
        profiles = user.relationship_profiles.with_discarded.order(:id).lock("FOR NO KEY UPDATE").to_a
        ConversationRecap
          .where(relationship_profile: profiles)
          .where.not(extraction_status: "not_requested")
          .lock
          .each do |recap|
            recap.update!(
              extraction_status: "not_requested",
              extraction_requested_at: nil,
              extraction_started_at: nil,
              extraction_completed_at: nil,
              extraction_approved_at: nil,
              extraction_error_code: nil
            )
          end
        ExtractedMemory.where(relationship_profile: profiles).lock.each(&:destroy!)

        RelationshipBriefing.where(relationship_profile: profiles).lock.each(&:destroy!)
        profiles.each(&:cancel_in_flight_briefing_generations!)

        GiftRecommendation.where(relationship_profile: profiles).lock.each(&:destroy!)
        profiles.each(&:cancel_in_flight_gift_recommendation_generations!)

        delete_event_plan_suggestions(user:, profiles:)

        reset_social_context_analysis(profiles)

        MemoryRecord.where(relationship_profile: profiles, source: "ai_inferred").find_each(&:destroy!)
        TimelineEntry.where(
          relationship_profile: profiles,
          entry_type: "ai_extraction",
          origin: "system"
        ).find_each(&:destroy!)
      end
    end

    def self.delete_event_plan_suggestions(user:, profiles:)
      EventPlan
        .where(user:, relationship_profile: profiles)
        .order(:id)
        .lock("FOR NO KEY UPDATE")
        .each do |plan|
          backup_plans = plan.backup_plans.reorder(:id).lock.to_a
          backup_options = BackupOption.where(backup_plan: backup_plans).reorder(:id).lock.to_a
          replacement_task_ids = backup_options
            .select { |option| option.promoted_at.present? }
            .flat_map(&:replacement_task_ids)
            .uniq
          plan.plan_tasks
            .where(id: replacement_task_ids, origin: %w[manual template])
            .reorder(:id)
            .lock
            .each { |task| task.update!(superseded_at: nil) }
          backup_plans.each(&:destroy!)
          ai_tasks = plan.plan_tasks.where(origin: "ai").reorder(:id).lock.to_a
          Reminder.where(plan_task: ai_tasks).order(:id).lock.each { |reminder| reminder.update!(plan_task: nil) }
          ai_tasks.each(&:destroy!)
          plan.update!(
            source_context: plan.planning_origin_context,
            generation_version: plan.generation_version + 1
          )
        end
    end
    private_class_method :delete_event_plan_suggestions

    def self.reset_social_context_analysis(profiles)
      notes_by_profile = SocialContextNote
        .where(relationship_profile: profiles)
        .order(:relationship_profile_id, :id)
        .lock
        .group_by(&:relationship_profile_id)

      profiles.each do |profile|
        message_context_changed = false
        notes_by_profile.fetch(profile.id, []).each do |note|
          message_context_changed = note.clear_ai_analysis! || message_context_changed
        end
        profile.cancel_in_flight_message_draft_generations! if message_context_changed
      end
    end
    private_class_method :reset_social_context_analysis
  end
end
