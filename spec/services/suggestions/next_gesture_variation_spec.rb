require "rails_helper"

RSpec.describe Suggestions::NextGestureVariation do
  it "skips hidden alternatives and stops when every alternative is hidden" do
    now = Time.zone.local(2026, 8, 19, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)

    Timecop.freeze(now) do
      low = Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of: now,
        gesture_variation: "low"
      ).find(&:gesture?)
      medium = Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of: now,
        gesture_variation: "medium"
      ).find(&:gesture?)
      high = Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of: now,
        gesture_variation: "high"
      ).find(&:gesture?)
      create(:suggestion_feedback, user:, relationship_profile: profile, fingerprint: medium.fingerprint, acted_at: now)

      expect(described_class.call(user:, relationship_profile: profile, suggestion: low, as_of: now)).to eq("high")

      create(:suggestion_feedback, user:, relationship_profile: profile, fingerprint: high.fingerprint, dismissed_at: now)

      expect(described_class.call(user:, relationship_profile: profile, suggestion: low, as_of: now)).to be_nil
    end
  end

  it "fails closed when the profile is not owned by the user" do
    profile = create(:relationship_profile)
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile, gesture_variation: "low").find(&:gesture?)

    expect(described_class.call(user: create(:user), relationship_profile: profile, suggestion:)).to be_nil
  end
end
