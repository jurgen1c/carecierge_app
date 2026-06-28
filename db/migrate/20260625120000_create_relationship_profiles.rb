class CreateRelationshipProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :relationship_profiles, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :first_name, null: false
      t.string :last_name
      t.string :preferred_name
      t.string :pronouns
      t.string :relationship_type_name
      t.date :birthday
      t.text :notes
      t.text :private_notes
      t.datetime :discarded_at
      t.string :slug

      t.timestamps
    end

    add_index :relationship_profiles, [ :user_id, :discarded_at ]
    add_index :relationship_profiles, :first_name
    add_index :relationship_profiles, :last_name
    add_index :relationship_profiles, :preferred_name
    add_index :relationship_profiles, :relationship_type_name
    add_index :relationship_profiles, :slug, unique: true
  end
end
