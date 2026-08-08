module DataDeletions
  class DeleteAiData
    def self.call(user:)
      profile_scope = user.relationship_profiles.with_discarded

      MemoryRecord.where(relationship_profile: profile_scope, source: "ai_inferred").find_each(&:destroy!)
      TimelineEntry.where(
        relationship_profile: profile_scope,
        entry_type: "ai_extraction",
        origin: "system"
      ).find_each(&:destroy!)
    end
  end
end
