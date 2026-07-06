require 'rails_helper'
require Rails.root.join("db/data/20260705160100_backfill_user_onboarding_completed_at")

RSpec.describe BackfillUserOnboardingCompletedAt do
  include ActiveSupport::Testing::TimeHelpers

  describe "#up" do
    it "does not overwrite users who completed onboarding after batch selection" do
      completed_at = 2.days.ago.change(usec: 0)
      user = create(:user, onboarding_completed_at: completed_at)
      create(:relationship_profile, user:)
      migration = described_class.new

      allow(migration).to receive(:users_with_relationship_profiles).and_return([ user.id ], [])

      travel_to(Time.current.change(usec: 0)) do
        migration.up
      end

      expect(user.reload.onboarding_completed_at).to eq(completed_at)
    end
  end
end
