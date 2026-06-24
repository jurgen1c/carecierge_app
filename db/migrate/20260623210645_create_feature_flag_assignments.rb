class CreateFeatureFlagAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flag_assignments, id: :uuid do |t|
      t.references :feature_flag, null: false, foreign_key: true, type: :uuid
      t.string :target_kind, null: false
      t.string :target_value, null: false
      t.boolean :enabled, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :feature_flag_assignments, [ :feature_flag_id, :target_kind, :target_value ],
              unique: true,
              name: "index_feature_flag_assignments_on_flag_and_target"
    add_index :feature_flag_assignments, [ :target_kind, :target_value ]
  end
end
