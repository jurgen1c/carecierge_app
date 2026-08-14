module DataDeletions
  class DeleteAiData
    def self.call(user:)
      ApplicationRecord.transaction do
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

        reset_social_context_analysis(profiles)

        MemoryRecord.where(relationship_profile: profiles, source: "ai_inferred").find_each(&:destroy!)
        TimelineEntry.where(
          relationship_profile: profiles,
          entry_type: "ai_extraction",
          origin: "system"
        ).find_each(&:destroy!)
      end
    end

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
