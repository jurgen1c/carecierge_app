class CreateMarketplaceListings < ActiveRecord::Migration[8.1]
  def change
    create_table :marketplace_listings, id: :uuid do |t|
      t.string :name, null: false
      t.string :category, null: false
      t.string :service_area, null: false
      t.string :occasion_types, array: true, default: [], null: false
      t.text :relationship_use_cases, null: false
      t.text :curated_summary, null: false
      t.string :provider_name, null: false
      t.text :provider_details, null: false
      t.string :source_url, null: false
      t.date :reviewed_on, null: false
      t.boolean :published, default: false, null: false
      t.timestamps
    end
    add_index :marketplace_listings, [ :published, :category ]
    add_reference :vendors, :marketplace_listing, type: :uuid, foreign_key: { on_delete: :nullify }
    add_index :vendors, [ :user_id, :marketplace_listing_id ], unique: true,
      where: "marketplace_listing_id IS NOT NULL", name: "index_vendors_on_owner_and_marketplace_listing"
  end
end
