class CreateVendorsAndEventPlanVendors < ActiveRecord::Migration[8.1]
  def change
    create_table :vendors, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :category, null: false
      t.string :location
      t.integer :minimum_price_cents
      t.integer :maximum_price_cents
      t.text :availability
      t.jsonb :occasion_types, null: false, default: []
      t.jsonb :preference_tags, null: false, default: []
      t.text :fit_notes
      t.string :source_kind, null: false, default: "manual"
      t.string :source_name
      t.string :source_url
      t.timestamps
    end

    add_index :vendors, [ :user_id, :category ]
    add_index :vendors, "user_id, lower(name)", name: "index_vendors_on_user_and_lower_name"
    add_index :vendors, :occasion_types, using: :gin
    add_index :vendors, :preference_tags, using: :gin
    add_check_constraint :vendors,
      "minimum_price_cents IS NULL OR minimum_price_cents >= 0",
      name: "vendors_minimum_price_nonnegative"
    add_check_constraint :vendors,
      "maximum_price_cents IS NULL OR maximum_price_cents >= 0",
      name: "vendors_maximum_price_nonnegative"
    add_check_constraint :vendors,
      "minimum_price_cents IS NULL OR maximum_price_cents IS NULL OR minimum_price_cents <= maximum_price_cents",
      name: "vendors_price_range_ordered"

    create_table :event_plan_vendors, id: :uuid do |t|
      t.references :event_plan, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :vendor, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :event_plan_vendors, [ :event_plan_id, :vendor_id ], unique: true
  end
end
