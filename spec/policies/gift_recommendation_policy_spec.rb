require "rails_helper"

RSpec.describe GiftRecommendationPolicy, type: :policy do
  it "allows only the owning account to update or dismiss a recommendation" do
    recommendation = create(:gift_recommendation)

    expect(described_class.new(recommendation.user, recommendation).update?).to be(true)
    expect(described_class.new(recommendation.user, recommendation).destroy?).to be(true)
    expect(described_class.new(create(:user), recommendation).update?).to be(false)
  end
end
