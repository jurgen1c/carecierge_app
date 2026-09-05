class CreateMessagingFoundations < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :messaging_connection_generation, :integer, null: false, default: 0
    create_table :messaging_connections, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: 'gmail'
      t.string :status, null: false, default: 'connected'
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.timestamps
    end
    create_table :imported_message_contexts, id: :uuid do |t|
      t.references :messaging_connection, type: :uuid, null: false, foreign_key: true
      t.string :source_key, null: false
      t.text :external_id, null: false
      t.text :thread_id, null: false
      t.text :subject, null: false
      t.text :snippet, null: false
      t.text :reply_draft
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :imported_message_contexts, [ :messaging_connection_id, :source_key ], unique: true
  end
end
