class CreateMoodNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :mood_notes, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :category, null: false
      t.text :observation, null: false
      t.datetime :observed_at, null: false
      t.text :supportive_action
      t.datetime :follow_up_at
      t.boolean :timeline_visible, null: false, default: true

      t.timestamps
    end

    add_index :mood_notes, [ :relationship_profile_id, :observed_at ]
    add_index :mood_notes, [ :relationship_profile_id, :category ]
    add_index :mood_notes, [ :relationship_profile_id, :follow_up_at ]
  end
end
