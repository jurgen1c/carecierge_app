class CreatePersonalTouchChecklistsAndItems < ActiveRecord::Migration[8.1]
  def change
    create_table :personal_touch_checklists, id: :uuid do |t|
      t.references :relationship_profile, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.references :event_plan, null: true, type: :uuid, index: false, foreign_key: { on_delete: :cascade }
      t.references :important_date, null: true, type: :uuid, index: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :personal_touch_checklists, :event_plan_id,
      unique: true,
      where: "event_plan_id IS NOT NULL",
      name: "idx_personal_touch_checklists_unique_event_plan"
    add_index :personal_touch_checklists, :important_date_id,
      unique: true,
      where: "important_date_id IS NOT NULL",
      name: "idx_personal_touch_checklists_unique_important_date"
    add_check_constraint :personal_touch_checklists,
      "(event_plan_id IS NOT NULL) <> (important_date_id IS NOT NULL)",
      name: "personal_touch_checklists_exactly_one_moment"

    create_table :personal_touch_items, id: :uuid do |t|
      t.references :personal_touch_checklist, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :category, null: false
      t.text :title, null: false
      t.text :details
      t.string :origin, null: false, default: "manual"
      t.string :status, null: false, default: "active"
      t.integer :position, null: false, default: 0
      t.text :source_context, null: false, default: "[]"
      t.datetime :completed_at
      t.datetime :dismissed_at

      t.timestamps
    end

    add_index :personal_touch_items, [ :personal_touch_checklist_id, :status, :position ],
      name: "idx_personal_touch_items_checklist_status_position"
    add_check_constraint :personal_touch_items,
      "category IN ('preference', 'constraint', 'message', 'gift', 'dietary_need', 'accessibility_need', 'logistics', 'follow_up')",
      name: "personal_touch_items_category"
    add_check_constraint :personal_touch_items,
      "origin IN ('manual', 'suggested')",
      name: "personal_touch_items_origin"
    add_check_constraint :personal_touch_items,
      "status IN ('active', 'completed', 'dismissed')",
      name: "personal_touch_items_status"
  end
end
