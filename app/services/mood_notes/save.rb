module MoodNotes
  class Save
    def self.call(note)
      MoodNote.transaction do
        note.save!
        if note.timeline_visible?
          entry = note.timeline_entry || note.relationship_profile.timeline_entries.build(source_record: note)
          entry.update!(entry_type: "mood_note", origin: "system", title: note.display_title,
            body: note.supportive_action, occurred_at: note.observed_at)
        else
          note.timeline_entry&.destroy!
        end
        Interaction.sync_from_source!(note)
      end
      true
    rescue ActiveRecord::RecordInvalid
      false
    end
  end
end
