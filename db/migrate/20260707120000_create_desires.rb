class CreateDesires < ActiveRecord::Migration[8.1]
  def change
    create_table :desires, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.string :category, null: false
      t.string :status, null: false, default: "active"
      t.string :source, null: false, default: "manual"
      t.date :captured_on
      t.text :notes

      t.timestamps
    end

    add_index :desires, [ :relationship_profile_id, :status ]
    add_index :desires, [ :relationship_profile_id, :category ]
    add_index :desires, [ :relationship_profile_id, :captured_on ]
  end
end
