class CreateContactCadences < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_cadences, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.integer :interval_days, null: false

      t.timestamps
    end

    add_check_constraint :contact_cadences,
      "interval_days IN (7, 14, 30, 60, 90)",
      name: "contact_cadences_supported_interval_days"
  end
end
