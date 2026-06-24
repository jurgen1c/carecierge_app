require "rails_helper"

RSpec.describe FeatureFlagPolicy do
  subject(:policy) { described_class.new(user, FeatureFlag) }

  let!(:feature_flag) { create(:feature_flag) }

  context "with an admin user" do
    let(:user) { build(:user, :admin) }

    it "allows index access and resolves all flags" do
      expect(policy.index?).to be(true)
      expect(described_class::Scope.new(user, FeatureFlag).resolve).to contain_exactly(feature_flag)
    end
  end

  context "with a non-admin user" do
    let(:user) { build(:user) }

    it "denies index access and resolves no flags" do
      expect(policy.index?).to be(false)
      expect(described_class::Scope.new(user, FeatureFlag).resolve).to be_empty
    end
  end

  context "without a user" do
    let(:user) { nil }

    it "denies index access and resolves no flags" do
      expect(policy.index?).to be(false)
      expect(described_class::Scope.new(user, FeatureFlag).resolve).to be_empty
    end
  end
end
