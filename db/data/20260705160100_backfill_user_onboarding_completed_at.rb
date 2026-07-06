class BackfillUserOnboardingCompletedAt < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 1_000

  def up
    loop do
      user_ids = users_with_relationship_profiles
      break if user_ids.empty?

      quoted_ids = user_ids.map { |user_id| connection.quote(user_id) }.join(", ")

      execute <<~SQL.squish
        UPDATE users
        SET onboarding_completed_at = CURRENT_TIMESTAMP
        WHERE id IN (#{quoted_ids})
      SQL
    end
  end

  def down
    # Backfilled completion state is intentionally not reversed.
  end

  private

  def users_with_relationship_profiles
    select_values <<~SQL.squish
      SELECT users.id
      FROM users
      WHERE users.onboarding_completed_at IS NULL
        AND EXISTS (
          SELECT 1
          FROM relationship_profiles
          WHERE relationship_profiles.user_id = users.id
        )
      ORDER BY users.id
      LIMIT #{BATCH_SIZE}
    SQL
  end
end
