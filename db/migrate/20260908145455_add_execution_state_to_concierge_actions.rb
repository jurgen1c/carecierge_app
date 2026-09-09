class AddExecutionStateToConciergeActions < ActiveRecord::Migration[8.1]
  def change
    add_column :concierge_actions, :run_token, :uuid
    add_column :concierge_actions, :started_at, :datetime
    add_column :concierge_actions, :attempts, :integer, null: false, default: 0
    add_column :concierge_actions, :error_code, :string
    remove_check_constraint :concierge_actions, name: "concierge_actions_state",
      expression: "state IN ('pending', 'awaiting_approval', 'approved', 'succeeded', 'failed', 'rejected')"
    add_check_constraint :concierge_actions,
      "state IN ('pending', 'awaiting_approval', 'approved', 'running', 'succeeded', 'failed', 'rejected')",
      name: "concierge_actions_state"
  end
end
