class CreateExtractedMemories < ActiveRecord::Migration[8.1]
  def change
    add_column :conversation_recaps, :extraction_started_at, :datetime
    add_column :conversation_recaps, :extraction_completed_at, :datetime
    add_column :conversation_recaps, :extraction_error_code, :string

    create_table :extracted_memories, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :conversation_recap, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :reviewed_by, foreign_key: { to_table: :users, on_delete: :nullify }, type: :uuid
      t.references :canonical_memory_record, foreign_key: { to_table: :memory_records, on_delete: :nullify }, type: :uuid, index: { unique: true }
      t.string :category, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.text :source_excerpt, null: false
      t.string :confidence, null: false
      t.string :status, null: false, default: "pending"
      t.string :corrected_title
      t.text :corrected_body
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :extracted_memories, %i[relationship_profile_id status]
    add_index :extracted_memories, %i[conversation_recap_id status]
  end
end
