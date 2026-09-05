class CreateExternalProviderActions < ActiveRecord::Migration[8.1]
  def change
    create_table :external_provider_actions, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      %i[gift_purchase_plan event_plan booking vendor_quote reminder].each do |context|
        t.references context, type: :uuid, foreign_key: { on_delete: :cascade }
      end
      t.text :provider_name, null: false
      t.string :provider_kind, null: false
      t.string :action_kind, null: false
      t.string :status, null: false, default: "pending"
      t.text :source_label, null: false
      t.text :source_url
      t.text :external_reference
      t.text :failure_details
      t.datetime :recorded_at, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :external_provider_actions, [ :relationship_profile_id, :created_at, :id ], name: :index_provider_actions_on_profile_history
  end
end
