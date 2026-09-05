class CreateGiftBoxes < ActiveRecord::Migration[8.1]
  def change
    create_table :gift_boxes, id: :uuid do |t|
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :name, null: false
      t.text :occasion, null: false
      t.text :notes
      t.text :constraints
      t.decimal :budget, precision: 12, scale: 2
      t.string :currency, default: "USD", null: false
      t.date :delivery_on
      t.integer :lock_version, default: 0, null: false
      t.timestamps
    end
    create_table :gift_box_items, id: :uuid do |t|
      t.references :gift_box, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :name, null: false
      t.text :notes
      t.text :vendor
      t.text :purchase_url
      t.decimal :cost, precision: 12, scale: 2
      t.boolean :purchased, default: false, null: false
      t.boolean :completed, default: false, null: false
      t.timestamps
    end
  end
end
