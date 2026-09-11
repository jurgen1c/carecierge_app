module Concierge
  class RelatedSources
    # Domain-owned side effects only. These associations never come from tool arguments.
    ASSOCIATIONS = {
      "MessageDraft" => { "DraftRevision" => :draft_revisions },
      "VendorQuote" => { "Reminder" => :reminders },
      "ExtractedMemory" => { "ConversationRecap" => :conversation_recap, "ApprovalRequest" => :approval_requests },
      "MemoryRecord" => { "ApprovalRequest" => :approval_requests },
      "EventPlan" => { "PlanTask" => :plan_tasks, "Reminder" => :reminders },
      "PlanTask" => { "Reminder" => :reminders },
      "ConversationRecap" => { "Interaction" => :interaction, "TimelineEntry" => :timeline_entry, "ExtractedMemory" => :extracted_memories },
      "MoodNote" => { "Interaction" => :interaction, "TimelineEntry" => :timeline_entry },
      "Commitment" => { "Reminder" => :reminders, "TimelineEntry" => :timeline_entry },
      "ImportantDate" => { "Reminder" => :reminders },
      "Booking" => { "Reminder" => :reminders, "PlanTask" => :plan_task, "TimelineEntry" => :timeline_entry },
      "Vendor" => { "VendorOption" => :vendor_options, "VendorQuote" => :vendor_quotes },
      "Gift" => { "GiftPurchasePlan" => :purchase_plan }
    }.freeze

    def self.capture(target:, turn:, profile: nil)
      known = History.current_sources(turn).group_by { |reference| reference["record_type"] }
      # Interaction creation, edits and derived recap/mood changes affect the
      # profile's contact-time aggregate even when no target existed beforehand.
      cadence = known.fetch("ContactCadence", []).select { |reference| reference["relationship_profile_id"] == profile&.id }
      # Full generation provenance can depend on any edited input for this profile.
      # Recheck only already-referenced outputs and retire only those now invalid.
      generated = %w[PlanTask BackupOption DraftRevision RelationshipBriefing GiftRecommendation Suggestion].flat_map { |type| known.fetch(type, []) }
        .select { |reference| reference["relationship_profile_id"] == profile&.id }
      return cadence + generated unless target
      target = target.subject if target.is_a?(ApprovalRequest) && target.subject.is_a?(ExtractedMemory)

      cadence + generated + ASSOCIATIONS.fetch(target.class.base_class.name, {}).flat_map do |type, association|
        references = known.fetch(type, [])
        next [] if references.empty?

        ids = target.association(association).scope.where(id: references.pluck("id")).pluck(:id)
        references.select { |reference| ids.include?(reference["id"]) }
      end
    end

    def self.retired(references, turn:)
      references.filter_map do |reference|
        next if History.source_current?(reference, user: turn.conversation.user, turn:)
        reference.slice("record_type", "id")
      end
    end
  end
end
