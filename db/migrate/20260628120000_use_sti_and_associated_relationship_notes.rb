class UseStiAndAssociatedRelationshipNotes < ActiveRecord::Migration[8.1]
  class MigrationRichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"
  end

  class MigrationRelationshipNote < ActiveRecord::Base
    self.table_name = "relationship_notes"
  end

  DEFAULT_TYPE = "OtherRelationshipProfile"
  TYPE_BY_LEGACY_LABEL = {
    "acquaintance" => "AcquaintanceRelationshipProfile",
    "advisor" => "AdvisorRelationshipProfile",
    "aunt" => "AuntRelationshipProfile",
    "best friend" => "BestFriendRelationshipProfile",
    "boss" => "BossRelationshipProfile",
    "brother" => "BrotherRelationshipProfile",
    "business partner" => "BusinessPartnerRelationshipProfile",
    "care recipient" => "CareRecipientRelationshipProfile",
    "caregiver" => "CaregiverRelationshipProfile",
    "child" => "ChildRelationshipProfile",
    "classmate" => "ClassmateRelationshipProfile",
    "client" => "ClientRelationshipProfile",
    "coach" => "CoachRelationshipProfile",
    "colleague" => "ColleagueRelationshipProfile",
    "community member" => "CommunityMemberRelationshipProfile",
    "cousin" => "CousinRelationshipProfile",
    "coworker" => "CoworkerRelationshipProfile",
    "customer" => "CustomerRelationshipProfile",
    "dad" => "FatherRelationshipProfile",
    "daughter" => "DaughterRelationshipProfile",
    "direct report" => "DirectReportRelationshipProfile",
    "doctor" => "DoctorRelationshipProfile",
    "extended family" => "ExtendedFamilyRelationshipProfile",
    "family" => "FamilyRelationshipProfile",
    "father" => "FatherRelationshipProfile",
    "fiance" => "FianceRelationshipProfile",
    "fiancee" => "FianceeRelationshipProfile",
    "friend" => "FriendRelationshipProfile",
    "grandchild" => "GrandchildRelationshipProfile",
    "grandfather" => "GrandfatherRelationshipProfile",
    "grandmother" => "GrandmotherRelationshipProfile",
    "grandparent" => "GrandparentRelationshipProfile",
    "guardian" => "GuardianRelationshipProfile",
    "housemate" => "HousemateRelationshipProfile",
    "in law" => "InLawRelationshipProfile",
    "in-law" => "InLawRelationshipProfile",
    "manager" => "ManagerRelationshipProfile",
    "mentee" => "MenteeRelationshipProfile",
    "mentor" => "MentorRelationshipProfile",
    "mom" => "MotherRelationshipProfile",
    "mother" => "MotherRelationshipProfile",
    "neighbor" => "NeighborRelationshipProfile",
    "neighbour" => "NeighborRelationshipProfile",
    "nephew" => "NephewRelationshipProfile",
    "niece" => "NieceRelationshipProfile",
    "parent" => "ParentRelationshipProfile",
    "partner" => "PartnerRelationshipProfile",
    "roommate" => "RoommateRelationshipProfile",
    "sibling" => "SiblingRelationshipProfile",
    "significant other" => "SignificantOtherRelationshipProfile",
    "sister" => "SisterRelationshipProfile",
    "son" => "SonRelationshipProfile",
    "spouse" => "SpouseRelationshipProfile",
    "step parent" => "StepparentRelationshipProfile",
    "stepparent" => "StepparentRelationshipProfile",
    "student" => "StudentRelationshipProfile",
    "teacher" => "TeacherRelationshipProfile",
    "teammate" => "TeammateRelationshipProfile",
    "therapist" => "TherapistRelationshipProfile",
    "uncle" => "UncleRelationshipProfile",
    "vendor" => "VendorRelationshipProfile"
  }.freeze
  LABEL_BY_TYPE = TYPE_BY_LEGACY_LABEL.values.uniq.each_with_object(DEFAULT_TYPE => "Other") do |type, labels|
    labels[type] = type.delete_suffix("RelationshipProfile").underscore.humanize
  end.merge(
    "InLawRelationshipProfile" => "In-law"
  ).freeze

  def up
    add_column :relationship_profiles, :type, :string

    migrate_profile_types_to_sti

    change_column_null :relationship_profiles, :type, false
    add_index :relationship_profiles, :type

    migrate_profile_rich_text_to_relationship_notes

    remove_index :relationship_profiles, :relationship_type_name if index_exists?(:relationship_profiles, :relationship_type_name)
    remove_column :relationship_profiles, :relationship_type_name if column_exists?(:relationship_profiles, :relationship_type_name)
  end

  def down
    add_column :relationship_profiles, :relationship_type_name, :string unless column_exists?(:relationship_profiles, :relationship_type_name)

    restore_profile_types_to_labels

    add_index :relationship_profiles, :relationship_type_name unless index_exists?(:relationship_profiles, :relationship_type_name)
    restore_first_relationship_note_to_profile_rich_text
    remove_index :relationship_profiles, :type if index_exists?(:relationship_profiles, :type)
    remove_column :relationship_profiles, :type if column_exists?(:relationship_profiles, :type)
  end

  private

  def migrate_profile_types_to_sti
    execute <<~SQL.squish
      UPDATE relationship_profiles
      SET type = CASE lower(trim(relationship_type_name))
        #{type_case_clauses}
        ELSE #{quote(DEFAULT_TYPE)}
      END
    SQL
  end

  def restore_profile_types_to_labels
    execute <<~SQL.squish
      UPDATE relationship_profiles
      SET relationship_type_name = CASE type
        #{label_case_clauses}
        ELSE 'Other'
      END
    SQL
  end

  def type_case_clauses
    TYPE_BY_LEGACY_LABEL.map do |label, type|
      "WHEN #{quote(label)} THEN #{quote(type)}"
    end.join("\n")
  end

  def label_case_clauses
    LABEL_BY_TYPE.map do |type, label|
      "WHEN #{quote(type)} THEN #{quote(label)}"
    end.join("\n")
  end

  def quote(value)
    connection.quote(value)
  end

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
