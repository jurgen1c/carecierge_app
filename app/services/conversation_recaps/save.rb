module ConversationRecaps
  class Save
    def self.call(recap, extraction_enabled:)
      requested = false
      recap.relationship_profile.with_lock do
        ConversationRecap.transaction do
          recap.save!
          requested = recap.saved_change_to_extraction_status?(from: "not_requested", to: "requested")
          entry = recap.timeline_entry || recap.relationship_profile.timeline_entries.build(source_record: recap)
          entry.update!(entry_type: "conversation_recap", origin: "system", title: recap.title, body: recap.body, occurred_at: recap.occurred_at)
          Interaction.sync_from_source!(recap)
        end
      end
      MemoryExtractionJob.perform_later(recap) if requested && extraction_enabled
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
