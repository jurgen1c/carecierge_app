class UseStiAndAssociatedRelationshipNotes < ActiveRecord::Migration[8.1]
  class MigrationRichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"
  end

  class MigrationRelationshipNote < ActiveRecord::Base
    self.table_name = "relationship_notes"
  end

  def up
    migrate_profile_rich_text_to_relationship_notes
  end

  def down
    restore_first_relationship_note_to_profile_rich_text
  end

  private

  def migrate_profile_rich_text_to_relationship_notes
    MigrationRichText
      .where(record_type: "RelationshipProfile", name: %w[notes private_notes])
      .find_each do |rich_text|
        note = MigrationRelationshipNote.create!(
          relationship_profile_id: rich_text.record_id,
          category: rich_text.name == "private_notes" ? "Private" : "General",
          private: rich_text.name == "private_notes",
          created_at: rich_text.created_at,
          updated_at: rich_text.updated_at
        )

        rich_text.update!(
          record_type: "RelationshipNote",
          record_id: note.id,
          name: "body"
        )
      end
  end

  def restore_first_relationship_note_to_profile_rich_text
    MigrationRelationshipNote.order(:created_at).find_each do |note|
      rich_text = MigrationRichText.find_by(record_type: "RelationshipNote", record_id: note.id, name: "body")
      next unless rich_text

      rich_text.update!(
        record_type: "RelationshipProfile",
        record_id: note.relationship_profile_id,
        name: note.private ? "private_notes" : "notes"
      )
    rescue ActiveRecord::RecordNotUnique
      rich_text.destroy!
    end
  end
end
