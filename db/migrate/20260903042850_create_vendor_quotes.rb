class CreateVendorQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_quotes, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :event_plan, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :vendor, null: false, type: :uuid, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.text :scope_details, null: false
      t.date :expires_on
      t.date :decision_due_on
      t.string :status, null: false, default: "draft"
      t.text :next_action
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index [ :event_plan_id, :status, :expires_on ], name: "index_vendor_quotes_on_plan_status_and_expiration"
      t.index [ :user_id, :created_at ]
      t.check_constraint "amount_cents >= 0", name: "vendor_quotes_amount_nonnegative"
      t.check_constraint "currency ~ '^[A-Z]{3}$'", name: "vendor_quotes_currency_format"
      t.check_constraint "status IN ('draft', 'awaiting_response', 'received', 'under_review', 'accepted', 'declined', 'expired')",
        name: "vendor_quotes_supported_status"
    end
  end
end
