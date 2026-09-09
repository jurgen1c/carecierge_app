module Concierge
  class Clarify
    def self.available?(action:)
      return false unless action.name == "people.clarify" && action.state == "succeeded"
      turn = action.turn
      return false unless turn.state == "completed" && action.result["clarification_turn_id"].nil?
      return false if %w[private_note_ids vault_item_ids].any? { |key| Array(turn.context[key]).any? }
      return false if turn.conversation.turns.where.not(id: turn.id).where("created_at >= ?", turn.created_at).exists?
      return false unless turn.actions.all? { |entry| entry.state == "succeeded" && Catalog.fetch(entry.name).read_only }
      Context.verify!(turn:)
      History.sources_current?(turn)
    rescue Error, ActiveRecord::RecordNotFound
      false
    end

    def self.call(user:, action:, relationship_profile_id:)
      conversation = action.turn.conversation
      Pundit.authorize(user, conversation, :update?)
      user.with_lock("FOR NO KEY UPDATE") do
        conversation.lock!
        action.lock!
        if action.result["clarification_turn_id"]
          raise RequestConflict unless action.result["selected_relationship_profile_id"] == relationship_profile_id
          next conversation.turns.find(action.result["clarification_turn_id"])
        end
        raise RequestConflict unless available?(action:)
        choice = Array(action.result["records"]).find { |record| record["record_type"] == "RelationshipProfile" && record["id"] == relationship_profile_id }
        raise ActiveRecord::RecordNotFound unless choice
        profile = user.relationship_profiles.active.find(relationship_profile_id)
        profile.with_lock do
          raise RequestConflict unless History.source_current?(choice, user:, turn: action.turn)
          conversation.update!(relationship_profile: profile)
          resumed = Submit.call(user:, conversation:, content: action.turn.content, locale: action.turn.locale,
            request_key: Execute.fingerprint("person_choice", { "action_id" => action.id, "profile_id" => profile.id }))
          action.update!(result: action.result.merge("clarification_turn_id" => resumed.id, "selected_relationship_profile_id" => profile.id))
          resumed
        end
      end
    end
  end
end
