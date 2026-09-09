class AddExecutionOrderToConciergeActions < ActiveRecord::Migration[8.1]
  def change
    add_column :concierge_actions, :execution_order, :integer, null: false, default: 0
    reversible do |direction|
      direction.up do
        execute <<~SQL
          UPDATE concierge_actions AS actions SET execution_order = ordered.position
          FROM (SELECT id, ROW_NUMBER() OVER (PARTITION BY turn_id ORDER BY updated_at, created_at, id) AS position
                FROM concierge_actions) AS ordered
          WHERE actions.id = ordered.id
        SQL
      end
    end
    add_index :concierge_actions, [ :turn_id, :execution_order ], unique: true
  end
end
