class CreateMemoryRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :memory_records, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :body, null: false
      t.string :source, null: false, default: "user_confirmed"
      t.string :confidence, null: false, default: "confirmed"
      t.string :status, null: false, default: "active"
      t.date :stale_after
      t.datetime :review_queued_at
      t.datetime :reviewed_at
      t.datetime :high_impact_automation_approved_at

      t.timestamps
    end

    add_index :memory_records, [ :relationship_profile_id, :status ]
    add_index :memory_records, [ :relationship_profile_id, :confidence ]
    add_index :memory_records, [ :relationship_profile_id, :source ]
    add_index :memory_records, [ :relationship_profile_id, :stale_after ]
  end
end
