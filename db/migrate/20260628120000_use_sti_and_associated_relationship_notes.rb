class UseStiAndAssociatedRelationshipNotes < ActiveRecord::Migration[8.1]
  class MigrationRichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"
  end

  class MigrationRelationshipNote < ActiveRecord::Base
    self.table_name = "relationship_notes"
  end

  DEFAULT_TYPE = "OtherRelationshipProfile"

  def up
    add_column :relationship_profiles, :type, :string

    execute <<~SQL.squish
      UPDATE relationship_profiles
      SET type = CASE lower(trim(relationship_type_name))
        WHEN 'family' THEN 'FamilyRelationshipProfile'
        WHEN 'mentor' THEN 'MentorRelationshipProfile'
        WHEN 'colleague' THEN 'ColleagueRelationshipProfile'
        WHEN 'coworker' THEN 'ColleagueRelationshipProfile'
        WHEN 'neighbor' THEN 'NeighborRelationshipProfile'
        WHEN 'neighbour' THEN 'NeighborRelationshipProfile'
        WHEN 'friend' THEN 'FriendRelationshipProfile'
        ELSE '#{DEFAULT_TYPE}'
      END
    SQL

    change_column_null :relationship_profiles, :type, false
    add_index :relationship_profiles, :type

    migrate_profile_rich_text_to_relationship_notes

    remove_index :relationship_profiles, :relationship_type_name if index_exists?(:relationship_profiles, :relationship_type_name)
    remove_column :relationship_profiles, :relationship_type_name if column_exists?(:relationship_profiles, :relationship_type_name)
  end

  def down
    add_column :relationship_profiles, :relationship_type_name, :string unless column_exists?(:relationship_profiles, :relationship_type_name)

    execute <<~SQL.squish
      UPDATE relationship_profiles
      SET relationship_type_name = CASE type
        WHEN 'FamilyRelationshipProfile' THEN 'Family'
        WHEN 'MentorRelationshipProfile' THEN 'Mentor'
        WHEN 'ColleagueRelationshipProfile' THEN 'Colleague'
        WHEN 'NeighborRelationshipProfile' THEN 'Neighbor'
        WHEN 'FriendRelationshipProfile' THEN 'Friend'
        ELSE 'Other'
      END
    SQL

    add_index :relationship_profiles, :relationship_type_name unless index_exists?(:relationship_profiles, :relationship_type_name)
    restore_first_relationship_note_to_profile_rich_text
    remove_index :relationship_profiles, :type if index_exists?(:relationship_profiles, :type)
    remove_column :relationship_profiles, :type if column_exists?(:relationship_profiles, :type)
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
