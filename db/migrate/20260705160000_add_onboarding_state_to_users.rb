class AddOnboardingStateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_skipped_at, :datetime

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE users
          SET onboarding_completed_at = CURRENT_TIMESTAMP
          WHERE onboarding_completed_at IS NULL
            AND EXISTS (
              SELECT 1
              FROM relationship_profiles
              WHERE relationship_profiles.user_id = users.id
            )
        SQL
      end
    end
  end
end
