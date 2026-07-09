class CreateMemoryRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :memory_revisions, id: :uuid do |t|
      t.references :memory_record, null: false, foreign_key: true, type: :uuid
      t.references :user, null: true, foreign_key: true, type: :uuid
      t.text :previous_body, null: false
      t.text :revised_body, null: false
      t.text :note

      t.timestamps
    end

    add_index :memory_revisions, [ :memory_record_id, :created_at ]
  end
end
