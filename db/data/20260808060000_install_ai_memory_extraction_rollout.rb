# frozen_string_literal: true

class InstallAiMemoryExtractionRollout < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO feature_flags (id, key, name, description, enabled, metadata, created_at, updated_at)
      VALUES (
        gen_random_uuid(),
        'ai_memory_extraction',
        'AI memory extraction',
        'Allows opted-in conversation recaps to produce source-backed memory proposals for owner review.',
        FALSE,
        '{}',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (key) DO NOTHING
    SQL

    execute <<~SQL.squish
      UPDATE conversation_recaps
      SET extraction_status = 'failed',
          extraction_completed_at = CURRENT_TIMESTAMP,
          extraction_error_code = 'extraction_interrupted',
          updated_at = CURRENT_TIMESTAMP
      WHERE extraction_status IN ('requested', 'processing')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "The AI memory rollout may have been configured or retried after installation"
  end
end
