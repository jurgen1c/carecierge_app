module Concierge
  class Sources
    ASSOCIATIONS = {
      "MemoryRecord" => :memory_records, "ConversationRecap" => :conversation_recaps,
      "MoodNote" => :mood_notes, "Interaction" => :interactions, "TimelineEntry" => :timeline_entries,
      "Commitment" => :commitments, "Desire" => :desires, "ImportantDate" => :important_dates,
      "RelationshipPreference" => :relationship_preferences, "RelationshipNote" => :relationship_notes,
      "EventPlan" => :event_plans, "ExtractedMemory" => :extracted_memories, "Gift" => :gifts,
      "SocialContextNote" => :social_context_notes
    }.freeze

    def self.scope(profile:, association:, turn: nil)
      if profile.professional?
        return profile.public_send(association).none unless ProfessionalContext::COLLECTIONS.include?(association.to_s)
        return profile.work_context.selected(association.to_s)
      end
      scope = profile.public_send(association)
      case association
      when :social_context_notes then scope.suggestion_allowed.with_rich_text_body
      when :memory_records then scope.unprotected
      when :event_plans then scope.visible
      when :relationship_notes
        selected = Array(turn&.context&.fetch("private_note_ids", [])) + (turn&.context&.fetch("authored_private_notes", {}) || {}).keys
        scope.where.missing(:privacy_vault_item).where(private: false).or(
          scope.where.missing(:privacy_vault_item).where(id: selected, private: true)).includes(:rich_text_body)
      else scope
      end
    end
  end
end
