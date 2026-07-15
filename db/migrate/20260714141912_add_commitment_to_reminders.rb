class AddCommitmentToReminders < ActiveRecord::Migration[8.1]
  def change
    add_reference :reminders, :commitment, null: true, foreign_key: { on_delete: :cascade }, type: :uuid
  end
end
