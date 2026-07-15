class CreateCommitments < ActiveRecord::Migration[8.1]
  def change
    create_table :commitments, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :title, null: false
      t.text :notes
      t.date :due_on
      t.string :status, null: false, default: "open"
      t.datetime :completed_at

      t.timestamps
    end

    add_index :commitments, [ :relationship_profile_id, :status, :due_on ]
    add_index :commitments, [ :status, :due_on ], where: "status = 'open' AND due_on IS NOT NULL", name: "index_commitments_on_open_due_on"
  end
end
