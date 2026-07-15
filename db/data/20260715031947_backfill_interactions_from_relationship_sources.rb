# frozen_string_literal: true

class BackfillInteractionsFromRelationshipSources < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO interactions
        (id, relationship_profile_id, interaction_type, origin, occurred_at, source_type, source_id, created_at, updated_at)
      SELECT
        gen_random_uuid(), relationship_profile_id, 'conversation_recap', 'derived', occurred_at,
        'ConversationRecap', id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM conversation_recaps
      WHERE occurred_at <= CURRENT_TIMESTAMP
      ON CONFLICT (source_type, source_id) WHERE source_id IS NOT NULL DO NOTHING
    SQL

    execute <<~SQL.squish
      INSERT INTO interactions
        (id, relationship_profile_id, interaction_type, origin, occurred_at, source_type, source_id, created_at, updated_at)
      SELECT
        gen_random_uuid(), relationship_profile_id, 'mood_note', 'derived', observed_at,
        'MoodNote', id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM mood_notes
      WHERE observed_at <= CURRENT_TIMESTAMP
      ON CONFLICT (source_type, source_id) WHERE source_id IS NOT NULL DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Derived interactions cannot be distinguished from records created after this backfill"
  end
end
