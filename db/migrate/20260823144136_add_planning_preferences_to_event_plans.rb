class AddPlanningPreferencesToEventPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :event_plans, :tone, :string, null: false, default: "warm"
    add_column :event_plans, :effort_level, :string, null: false, default: "medium"

    add_check_constraint :event_plans,
      "tone IN ('understated', 'warm', 'celebratory', 'romantic')",
      name: "event_plans_supported_tone"
    add_check_constraint :event_plans,
      "effort_level IN ('low', 'medium', 'high')",
      name: "event_plans_supported_effort_level"
  end
end
