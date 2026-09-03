class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :event_plan, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :plan_task, null: true, type: :uuid, index: false, foreign_key: { on_delete: :nullify }
      t.string :booking_kind, null: false, default: "reservation"
      t.text :title, null: false
      t.text :provider_name, null: false
      t.datetime :starts_at, null: false
      t.string :time_zone, null: false, default: "UTC"
      t.text :location
      t.string :status, null: false, default: "planned"
      t.text :confirmation_details
      t.text :cancellation_policy
      t.text :notes
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.index [ :event_plan_id, :starts_at, :id ]
      t.index [ :event_plan_id, :status, :starts_at ]
      t.index [ :user_id, :created_at ]
      t.index :plan_task_id, unique: true, where: "plan_task_id IS NOT NULL", name: "index_bookings_on_unique_plan_task"
      t.check_constraint "booking_kind IN ('reservation', 'booking')", name: "bookings_supported_kind"
      t.check_constraint "status IN ('planned', 'requested', 'confirmed', 'completed', 'cancelled')",
        name: "bookings_supported_status"
    end
  end
end
