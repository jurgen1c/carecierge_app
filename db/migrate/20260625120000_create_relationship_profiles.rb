class CreateRelationshipProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :relationship_types, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :relationship_types, [ :user_id, :name ], unique: true

    create_table :relationship_profiles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :relationship_type, foreign_key: true, type: :uuid
      t.string :first_name, null: false
      t.string :last_name
      t.string :preferred_name
      t.string :pronouns
      t.date :birthday
      t.text :notes
      t.text :private_notes
      t.jsonb :structured_preferences, null: false, default: {}
      t.datetime :archived_at

      t.timestamps
    end

    add_index :relationship_profiles, [ :user_id, :archived_at ]
    add_index :relationship_profiles, :first_name
    add_index :relationship_profiles, :last_name
    add_index :relationship_profiles, :preferred_name

    create_table :contact_methods, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.string :value, null: false
      t.string :label
      t.boolean :preferred, null: false, default: false

      t.timestamps
    end

    add_index :contact_methods, [ :relationship_profile_id, :kind ]

    create_table :relationship_notes, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :category
      t.text :body, null: false
      t.boolean :private, null: false, default: false

      t.timestamps
    end

    add_index :relationship_notes, [ :relationship_profile_id, :private ]

    create_table :relationship_tags, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false

      t.timestamps
    end

    add_index :relationship_tags, [ :relationship_profile_id, :name ], unique: true
  end
end
