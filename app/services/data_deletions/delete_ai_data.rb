module DataDeletions
  class DeleteAiData
    def self.call(user:)
      profile_scope = user.relationship_profiles.with_discarded

      ApplicationRecord.transaction do
        ExtractedMemory.where(relationship_profile: profile_scope).lock.each(&:destroy!)
        ConversationRecap
          .where(relationship_profile: profile_scope)
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

        MemoryRecord.where(relationship_profile: profile_scope, source: "ai_inferred").find_each(&:destroy!)
        TimelineEntry.where(
          relationship_profile: profile_scope,
          entry_type: "ai_extraction",
          origin: "system"
        ).find_each(&:destroy!)
      end
    end
  end
end
