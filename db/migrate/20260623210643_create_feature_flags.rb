class CreateFeatureFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flags, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, null: false, default: false
      t.datetime :retired_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :feature_flags, :key, unique: true
    add_index :feature_flags, :retired_at
  end
end
