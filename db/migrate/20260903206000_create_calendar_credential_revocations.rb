class CreateCalendarCredentialRevocations < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_credential_revocations, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.integer :attempts, null: false, default: 0
      t.string :last_error_code
      t.datetime :retry_at, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index :retry_at
    end
  end
end
