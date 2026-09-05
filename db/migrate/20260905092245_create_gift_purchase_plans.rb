class CreateGiftPurchasePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :gift_purchase_plans, id: :uuid do |t|
      t.references :gift, type: :uuid, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.references :plan_task, type: :uuid, foreign_key: { on_delete: :nullify }
      t.decimal :budget, precision: 12, scale: 2
      t.string :currency, null: false, default: "USD"
      t.date :purchase_by
      t.date :expected_delivery_on
      t.date :follow_up_on
      t.string :purchase_status, null: false, default: "planning"
      t.string :delivery_status, null: false, default: "not_started"
      t.text :shipping_notes
      t.text :constraints
      t.text :follow_up_notes
      t.text :options, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
  end
end
