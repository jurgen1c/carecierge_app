class CreateFeedItemStates < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_item_states, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :item_key, null: false
      t.datetime :dismissed_at
      t.datetime :snoozed_until

      t.timestamps
    end

    add_index :feed_item_states, %i[user_id item_key], unique: true
    add_index :feed_item_states, %i[user_id snoozed_until], where: "snoozed_until IS NOT NULL"
    add_check_constraint :feed_item_states,
      "char_length(item_key) BETWEEN 1 AND 200",
      name: "feed_item_states_item_key_length"
    add_check_constraint :feed_item_states,
      "dismissed_at IS NOT NULL OR snoozed_until IS NOT NULL",
      name: "feed_item_states_active_state"
  end
end
