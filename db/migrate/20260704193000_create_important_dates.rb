class CreateImportantDates < ActiveRecord::Migration[8.1]
  def change
    create_table :important_dates, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :date_type, null: false
      t.string :title
      t.date :starts_on, null: false
      t.string :recurrence, null: false, default: "none"
      t.string :importance_level, null: false, default: "normal"
      t.string :reminder_schedule, null: false, default: "none"
      t.text :notes

      t.timestamps
    end

    add_index :important_dates, [ :relationship_profile_id, :starts_on ]
    add_index :important_dates, [ :relationship_profile_id, :date_type ]
    add_index :important_dates, [ :relationship_profile_id, :importance_level ]
  end
end
