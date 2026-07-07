class CreateDesireFulfillments < ActiveRecord::Migration[8.1]
  def change
    create_table :desire_fulfillments, id: :uuid do |t|
      t.references :desire, null: false, foreign_key: true, type: :uuid
      t.date :fulfilled_on, null: false
      t.text :notes

      t.timestamps
    end

    add_index :desire_fulfillments, [ :desire_id, :fulfilled_on ]
  end
end
