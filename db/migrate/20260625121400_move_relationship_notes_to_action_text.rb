class MoveRelationshipNotesToActionText < ActiveRecord::Migration[8.1]
  class RichText < ActiveRecord::Base
    self.table_name = "action_text_rich_texts"
  end

  class Profile < ActiveRecord::Base
    self.table_name = "relationship_profiles"
  end

  class Note < ActiveRecord::Base
    self.table_name = "relationship_notes"
  end

  def up
    migrate_column_to_rich_text(Profile, "RelationshipProfile", :notes)
    migrate_column_to_rich_text(Profile, "RelationshipProfile", :private_notes)
    migrate_column_to_rich_text(Note, "RelationshipNote", :body)

    remove_column :relationship_profiles, :notes, :text if column_exists?(:relationship_profiles, :notes)
    remove_column :relationship_profiles, :private_notes, :text if column_exists?(:relationship_profiles, :private_notes)
    remove_column :relationship_notes, :body, :text if column_exists?(:relationship_notes, :body)
  end

  def down
    add_column :relationship_profiles, :notes, :text unless column_exists?(:relationship_profiles, :notes)
    add_column :relationship_profiles, :private_notes, :text unless column_exists?(:relationship_profiles, :private_notes)
    add_column :relationship_notes, :body, :text unless column_exists?(:relationship_notes, :body)

    restore_rich_text_to_column(Profile, "RelationshipProfile", :notes)
    restore_rich_text_to_column(Profile, "RelationshipProfile", :private_notes)
    restore_rich_text_to_column(Note, "RelationshipNote", :body)

    Note.where(body: nil).update_all(body: "")
    change_column_null :relationship_notes, :body, false
  end

  private

  def migrate_column_to_rich_text(model, record_type, name)
    return unless column_exists?(model.table_name, name)

    model.reset_column_information
    now = Time.current

    model.where.not(name => [ nil, "" ]).find_each do |record|
      RichText.find_or_create_by!(record_type:, record_id: record.id, name: name.to_s) do |rich_text|
        rich_text.body = record.public_send(name)
        rich_text.created_at = record.created_at || now
        rich_text.updated_at = record.updated_at || now
      end
    end
  end

  def restore_rich_text_to_column(model, record_type, name)
    model.reset_column_information

    RichText.where(record_type:, name: name.to_s).find_each do |rich_text|
      model.where(id: rich_text.record_id).update_all(name => rich_text.body)
    end
  end
end
