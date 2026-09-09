module Concierge
  class EraseRelationship
    # The profile's destruction callback holds the owner lock throughout deletion.
    # Remove the complete referenced conversation: later prose can depend on its earlier turns.
    def self.call(profile:)
      profile.user.concierge_conversations.includes(turns: :actions).find_each do |conversation|
        linked = conversation.relationship_profile_id == profile.id ||
          conversation.turns.any? { |turn| turn.referenced_profile_ids.include?(profile.id) }
        conversation.destroy! if linked
      end
    end
  end
end
