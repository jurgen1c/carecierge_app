class CreateGifts < ActiveRecord::Migration[8.1]
  def change
    create_table :gifts, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :status, null: false, default: "idea"
      t.string :occasion
      t.integer :price_cents
      t.string :vendor
      t.date :given_on
      t.text :reaction
      t.string :outcome
      t.text :notes

      t.timestamps
    end

    add_index :gifts, [ :relationship_profile_id, :status ]
    add_index :gifts, [ :relationship_profile_id, :given_on ]
    add_index :gifts, "relationship_profile_id, lower(name)", name: "index_gifts_on_profile_and_lower_name"
    add_index :gifts, [ :relationship_profile_id, :outcome ]
  end
end
