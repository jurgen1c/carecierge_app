require "rails_helper"

RSpec.describe SuggestionFeedbackPolicy do
  subject(:policy) { described_class.new(user, feedback) }

  let(:owner) { create(:user) }
  let(:feedback) { create(:suggestion_feedback, user: owner, relationship_profile: create(:relationship_profile, user: owner)) }

  context "when the user owns the feedback" do
    let(:user) { owner }

    it "permits suggestion interactions" do
      expect(policy.feedback?).to be(true)
      expect(policy.dismiss?).to be(true)
      expect(policy.act?).to be(true)
    end
  end

  context "when another user owns the feedback" do
    let(:user) { create(:user) }

    it "forbids suggestion interactions" do
      expect(policy.feedback?).to be(false)
      expect(policy.dismiss?).to be(false)
      expect(policy.act?).to be(false)
    end
  end
end
