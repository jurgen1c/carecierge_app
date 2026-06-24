class CreateRolloutGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :rollout_groups, id: :uuid do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.jsonb :criteria, null: false, default: {}
      t.datetime :retired_at

      t.timestamps
    end

    add_index :rollout_groups, :key, unique: true
    add_index :rollout_groups, :retired_at
  end
end
