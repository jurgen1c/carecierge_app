class CreateGiftRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :gift_recommendations, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :gift, null: true, type: :uuid, foreign_key: { on_delete: :nullify }
      t.text :title, null: false
      t.text :rationale, null: false
      t.text :source_context, null: false
      t.integer :estimated_price_cents
      t.text :vendor
      t.text :occasion
      t.integer :budget_cents
      t.date :needed_by
      t.boolean :allow_repeats, null: false, default: false
      t.boolean :include_private_notes, null: false, default: false
      t.boolean :include_vault_context, null: false, default: false
      t.string :locale, null: false, default: "en"
      t.string :status, null: false, default: "generated"
      t.datetime :generated_at, null: false
      t.datetime :saved_at
      t.datetime :dismissed_at
      t.datetime :purchased_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :gift_recommendations,
      %i[relationship_profile_id status generated_at],
      name: "index_gift_recommendations_on_profile_status_generated"
    add_check_constraint :gift_recommendations,
      "status IN ('generated', 'saved', 'dismissed', 'purchased')",
      name: "gift_recommendations_supported_status"
    add_check_constraint :gift_recommendations,
      "estimated_price_cents IS NULL OR estimated_price_cents >= 0",
      name: "gift_recommendations_estimated_price_nonnegative"
    add_check_constraint :gift_recommendations,
      "budget_cents IS NULL OR budget_cents >= 0",
      name: "gift_recommendations_budget_nonnegative"

    add_column :relationship_profiles, :gift_recommendation_generation_version, :bigint, null: false, default: 0
  end
end
