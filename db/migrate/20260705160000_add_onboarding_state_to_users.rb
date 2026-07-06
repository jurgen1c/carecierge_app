class AddOnboardingStateToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_skipped_at, :datetime
  end
end
