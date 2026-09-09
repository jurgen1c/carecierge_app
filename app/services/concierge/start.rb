module Concierge
  class Start
    def self.call(user:, content:, request_key:, locale:, relationship_profile_id: nil, context: {}, vault_lease: nil)
      user.with_lock("FOR NO KEY UPDATE") do
        existing = user.concierge_conversations.joins(:turns).find_by(concierge_turns: { request_key: })
        if existing
          raise RequestConflict unless existing.relationship_profile_id == relationship_profile_id.presence
          Submit.call(user:, conversation: existing, content:, request_key:, locale:, context:, vault_lease:)
          next existing
        end

        profile = user.relationship_profiles.active.find(relationship_profile_id) if relationship_profile_id.present?
        conversation = user.concierge_conversations.create!(relationship_profile: profile)
        Submit.call(user:, conversation:, content:, request_key:, locale:, context:, vault_lease:)
        conversation
      end
    end
  end
end
