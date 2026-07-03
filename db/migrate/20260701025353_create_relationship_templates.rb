class CreateRelationshipTemplates < ActiveRecord::Migration[8.1]
  DEFAULT_DEFINITIONS = {
    "RelationshipProfiles::Spouse" => {
      key: "spouse",
      name: "Spouse",
      description: "Default reminders and care context for a spouse.",
      fields: [
        [ "anniversary", "Anniversary", "Important anniversaries or shared dates" ],
        [ "date_ideas", "Date ideas", "Ideas that would feel thoughtful" ],
        [ "love_language", "Love language", "Ways they most appreciate care" ],
        [ "favorite_restaurants", "Favorite restaurants", "Places they like or want to try" ],
        [ "emotional_triggers", "Emotional triggers", "Sensitive topics or situations to handle carefully" ],
        [ "gift_preferences", "Gift preferences", "Useful gift ideas and preferences" ]
      ]
    },
    "RelationshipProfiles::Boss" => {
      key: "boss",
      name: "Boss",
      description: "Default work-context fields for a manager or boss.",
      fields: [
        [ "communication_style", "Communication style", "How they prefer updates or questions" ],
        [ "current_priorities", "Current priorities", "Work that matters most right now" ],
        [ "reporting_preferences", "Reporting preferences", "How to share status or outcomes" ],
        [ "meeting_style", "Meeting style", "Useful meeting preferences and norms" ],
        [ "feedback_preferences", "Feedback preferences", "How they tend to give or receive feedback" ]
      ]
    },
    "RelationshipProfiles::Child" => {
      key: "child",
      name: "Child",
      description: "Default care-context fields for a child.",
      fields: [
        [ "school_events", "School events", "Upcoming school moments to remember" ],
        [ "favorite_activities", "Favorite activities", "Activities they enjoy most" ],
        [ "clothing_size", "Clothing size", "Current sizes or fit notes" ],
        [ "food_preferences", "Food preferences", "Foods they like or avoid" ],
        [ "allergies", "Allergies", "Allergies or sensitivities to keep visible" ],
        [ "milestones", "Milestones", "Recent or upcoming milestones" ]
      ]
    }
  }.freeze

  def change
    create_table :relationship_templates, id: :uuid do |t|
      t.string :key, null: false
      t.string :relationship_type, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.boolean :system, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :relationship_templates, :key, unique: true
    add_index :relationship_templates, :relationship_type, unique: true
    add_index :relationship_templates, [ :active, :position ]

    create_table :template_fields, id: :uuid do |t|
      t.references :relationship_template, null: false, foreign_key: true, type: :uuid
      t.string :key, null: false
      t.string :label, null: false
      t.text :prompt
      t.string :field_type, null: false, default: "text"
      t.boolean :required, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :template_fields, [ :relationship_template_id, :key ], unique: true
    add_index :template_fields, [ :relationship_template_id, :active, :position ]

    create_table :relationship_field_values, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.references :template_field, null: true, foreign_key: true, type: :uuid
      t.string :key
      t.string :label, null: false
      t.text :value
      t.boolean :hidden, null: false, default: false
      t.boolean :custom, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :relationship_field_values, [ :relationship_profile_id, :template_field_id ],
      unique: true,
      where: "template_field_id IS NOT NULL",
      name: "index_relationship_field_values_on_profile_and_template_field"
    add_index :relationship_field_values, "relationship_profile_id, lower((label)::text)",
      unique: true,
      where: "custom = true",
      name: "index_relationship_field_values_on_profile_and_lower_label"
    add_index :relationship_field_values, [ :relationship_profile_id, :hidden, :position ],
      name: "index_relationship_field_values_on_profile_hidden_position"

    reversible do |dir|
      dir.up { install_default_templates }
    end
  end

  private

  def install_default_templates
    now = Time.current

    DEFAULT_DEFINITIONS.each_with_index do |(relationship_type, definition), template_position|
      template_id = select_value(
        sanitize_sql([
          "SELECT id FROM relationship_templates WHERE key = ? LIMIT 1",
          definition[:key]
        ])
      ) || SecureRandom.uuid

      execute sanitize_sql([
        <<~SQL.squish,
          INSERT INTO relationship_templates (id, key, relationship_type, name, description, active, system, position, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, TRUE, TRUE, ?, ?, ?)
          ON CONFLICT (key) DO UPDATE SET
            relationship_type = EXCLUDED.relationship_type,
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            active = EXCLUDED.active,
            system = EXCLUDED.system,
            position = EXCLUDED.position,
            updated_at = EXCLUDED.updated_at
        SQL
        template_id,
        definition[:key],
        relationship_type,
        definition[:name],
        definition[:description],
        template_position,
        now,
        now
      ])

      definition[:fields].each_with_index do |(key, label, prompt), field_position|
        execute sanitize_sql([
          <<~SQL.squish,
            INSERT INTO template_fields (id, relationship_template_id, key, label, prompt, field_type, required, active, position, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, 'text', FALSE, TRUE, ?, ?, ?)
            ON CONFLICT (relationship_template_id, key) DO UPDATE SET
              label = EXCLUDED.label,
              prompt = EXCLUDED.prompt,
              field_type = EXCLUDED.field_type,
              required = EXCLUDED.required,
              active = EXCLUDED.active,
              position = EXCLUDED.position,
              updated_at = EXCLUDED.updated_at
          SQL
          SecureRandom.uuid,
          template_id,
          key,
          label,
          prompt,
          field_position,
          now,
          now
        ])
      end
    end
  end

  def sanitize_sql(statement)
    ActiveRecord::Base.sanitize_sql(statement)
  end
end
