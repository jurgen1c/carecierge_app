class CreateVendorAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_accounts, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, index: { unique: true }, foreign_key: { on_delete: :cascade }
      t.string :status, null: false, default: "draft"
      t.string :business_name, null: false, default: ""
      t.string :categories, array: true, null: false, default: []
      t.string :service_area, null: false, default: ""
      t.text :offerings, null: false, default: ""
      t.text :contact_channels, null: false, default: ""
      t.text :source_url, null: false, default: ""
      t.text :provenance, null: false, default: ""
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :vendor_accounts, [ :status, :updated_at ]
    add_check_constraint :vendor_accounts, "status IN ('draft', 'submitted', 'approved', 'rejected', 'suspended')", name: "vendor_accounts_valid_status"

    create_table :vendor_account_reviews, id: :uuid do |t|
      t.references :vendor_account, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor, type: :uuid, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.integer :profile_version, null: false
      t.text :reason
      t.text :profile_snapshot, null: false
      t.datetime :created_at, null: false
    end
    add_index :vendor_account_reviews, [ :vendor_account_id, :created_at ]
    add_reference :marketplace_listings, :vendor_account, type: :uuid, index: { unique: true }, foreign_key: { on_delete: :cascade }
  end
end
