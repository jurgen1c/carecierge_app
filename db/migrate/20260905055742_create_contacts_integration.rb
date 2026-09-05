class CreateContactsIntegration < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :contacts_connection_generation, :integer, null: false, default: 0
    create_table :contacts_connections, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: "google_contacts"
      t.string :status, null: false, default: "connected"
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.text :next_page_token
      t.datetime :last_refreshed_at
      t.timestamps
    end
    create_table :imported_contacts, id: :uuid do |t|
      t.references :contacts_connection, type: :uuid, null: false, foreign_key: true
      t.references :relationship_profile, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :provider_key, null: false
      t.text :external_id, null: false
      t.text :data, null: false
      t.text :applied_data
      t.text :previous_data
      t.string :decision, null: false, default: "pending"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :imported_contacts, [ :contacts_connection_id, :provider_key ], unique: true
  end
end
