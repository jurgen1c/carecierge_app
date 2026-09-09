module Concierge
  class ConfigureContext
    def self.call(user:, conversation:, attributes:, expected_version:)
      user.with_lock("FOR NO KEY UPDATE") do
        conversation.with_lock do
          Pundit.authorize(user, conversation, :update?)
          profile = user.relationship_profiles.active.find(conversation.relationship_profile_id)
          profile.with_lock do
            Pundit.authorize(user, profile, :update?)
            raise RequestConflict unless RecordVersion.for(profile) == expected_version

            changes = attributes.deep_stringify_keys
            raise InvalidArguments unless (changes.keys - %w[relationship_mode professional_context]).empty?
            if changes.key?("professional_context")
              raise InvalidArguments unless changes["professional_context"].is_a?(Hash)
              changes["professional_context"] = profile.professional_context.merge(changes["professional_context"])
            end
            profile.assign_attributes(changes)
            next conversation unless profile.changed?

            AuditEvents::Track.call(user:, actor: user, action: "relationship_profile.updated", target: profile,
              metadata: { changed_fields: "profile_details" }) { profile.save! }
            user.concierge_conversations.create!(relationship_profile: profile)
          end
        end
      end
    end
  end
end
