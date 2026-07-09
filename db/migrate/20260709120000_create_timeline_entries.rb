class CreateTimelineEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :timeline_entries, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :entry_type, null: false
      t.string :origin, null: false, default: "manual"
      t.string :title, null: false
      t.text :body
      t.datetime :occurred_at, null: false
      t.string :source_record_type
      t.uuid :source_record_id

      t.timestamps
    end

    add_index :timeline_entries, %i[relationship_profile_id occurred_at]
    add_index :timeline_entries, %i[relationship_profile_id entry_type]
    add_index :timeline_entries, %i[relationship_profile_id origin]
    add_index :timeline_entries, %i[source_record_type source_record_id]
  end
end
