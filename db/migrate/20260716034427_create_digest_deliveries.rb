class CreateDigestDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :digest_deliveries, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :channel, null: false
      t.string :mode, null: false
      t.datetime :scheduled_for, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :enqueued_at
      t.datetime :dispatched_at
      t.text :error_message

      t.timestamps
    end

    add_index :digest_deliveries, [ :user_id, :scheduled_for ], unique: true,
      name: "index_digest_deliveries_on_user_and_occurrence"
    add_index :digest_deliveries, :enqueued_at,
      where: "status IN ('pending', 'dispatching')",
      name: "index_digest_deliveries_on_recoverable_lease"
    add_check_constraint :digest_deliveries,
      "channel IN ('email', 'in_app')",
      name: "digest_deliveries_supported_channel"
    add_check_constraint :digest_deliveries,
      "mode IN ('daily', 'weekly')",
      name: "digest_deliveries_supported_mode"
    add_check_constraint :digest_deliveries,
      "status IN ('pending', 'dispatching', 'dispatched', 'skipped', 'failed', 'cancelled')",
      name: "digest_deliveries_supported_status"
  end
end
