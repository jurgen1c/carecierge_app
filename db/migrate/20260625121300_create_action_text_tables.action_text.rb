class CreateActionTextTables < ActiveRecord::Migration[8.1]
  def change
    return if table_exists?(:action_text_rich_texts)

    create_table :action_text_rich_texts, id: :uuid do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false, type: :uuid

      t.timestamps

      t.index [ :record_type, :record_id, :name ], name: "index_action_text_rich_texts_uniqueness", unique: true
    end
  end
end
