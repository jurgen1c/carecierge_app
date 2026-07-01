class CreateRelationshipNotes < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:relationship_notes)

    create_table :relationship_notes, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :category
      t.text :body, null: false
      t.boolean :private, null: false, default: false

      t.timestamps
    end

    add_index :relationship_notes, [ :relationship_profile_id, :private ]
  end
end
