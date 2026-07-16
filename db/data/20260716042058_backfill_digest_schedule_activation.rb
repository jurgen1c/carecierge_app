# frozen_string_literal: true

class BackfillDigestScheduleActivation < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE notification_preferences
      SET digest_schedule_changed_at = CURRENT_TIMESTAMP
      WHERE digest_mode IN ('daily', 'weekly')
        AND digest_schedule_changed_at IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Schedule boundaries may have changed after the digest activation backfill"
  end
end
