class CreateVendorShortlistsAndOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_shortlists, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :event_plan, null: true, type: :uuid, foreign_key: { on_delete: :cascade }
      t.text :title, null: false
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :vendor_shortlists, %i[user_id created_at]
    add_index :vendor_shortlists, %i[relationship_profile_id created_at],
      name: "index_vendor_shortlists_on_profile_and_created_at"

    create_table :vendor_options, id: :uuid do |t|
      t.references :vendor_shortlist, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :vendor, null: false, type: :uuid, foreign_key: true
      t.text :notes
      t.text :constraints
      t.text :next_action
      t.boolean :favorite, null: false, default: false
      t.string :decision, null: false, default: "considering"
      t.datetime :selected_at
      t.datetime :rejected_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :vendor_options, %i[vendor_shortlist_id vendor_id], unique: true
    add_index :vendor_options, :vendor_shortlist_id,
      unique: true,
      where: "decision = 'selected'",
      name: "index_vendor_options_on_one_selected_per_shortlist"
    add_check_constraint :vendor_options,
      "decision IN ('considering', 'rejected', 'selected')",
      name: "vendor_options_decision_check"
  end
end
