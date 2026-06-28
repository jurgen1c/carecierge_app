class CreateContactMethods < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:contact_methods)

    create_table :contact_methods, id: :uuid do |t|
      t.references :relationship_profile, null: false, foreign_key: true, type: :uuid
      t.string :kind, null: false
      t.string :value, null: false
      t.string :label
      t.boolean :preferred, null: false, default: false

      t.timestamps
    end

    add_index :contact_methods, [ :relationship_profile_id, :kind ], unique: true
  end
end
