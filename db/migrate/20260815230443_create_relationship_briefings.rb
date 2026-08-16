class CreateRelationshipBriefings < ActiveRecord::Migration[8.1]
  def change
    create_table :relationship_briefings, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :relationship_profile, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.text :interaction_context, null: false
      t.text :sections, null: false
      t.jsonb :context_categories, null: false, default: []
      t.string :status, null: false, default: "generated"
      t.string :locale, null: false, default: "en"
      t.boolean :include_private_notes, null: false, default: false
      t.boolean :include_vault_context, null: false, default: false
      t.datetime :generated_at, null: false
      t.datetime :saved_at
      t.datetime :dismissed_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :relationship_briefings,
      %i[relationship_profile_id generated_at],
      order: { generated_at: :desc },
      name: "index_relationship_briefings_on_profile_and_generated_at"
    add_index :relationship_briefings,
      :relationship_profile_id,
      unique: true,
      where: "status = 'generated'",
      name: "index_relationship_briefings_on_one_generated_per_profile"
    add_check_constraint :relationship_briefings,
      "status IN ('generated', 'saved', 'dismissed')",
      name: "relationship_briefings_supported_status"
    add_check_constraint :relationship_briefings,
      "locale IN ('en', 'es')",
      name: "relationship_briefings_supported_locale"
    add_check_constraint :relationship_briefings,
      "jsonb_typeof(context_categories) = 'array'",
      name: "relationship_briefings_context_categories_array"

    add_column :relationship_profiles, :briefing_generation_version, :bigint, null: false, default: 0
  end
end
