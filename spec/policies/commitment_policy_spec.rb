require "rails_helper"

RSpec.describe CommitmentPolicy do
  let(:user) { create(:user) }
  let(:commitment) { build(:commitment, relationship_profile: profile) }

  context "when the relationship belongs to the user" do
    let(:profile) { create(:relationship_profile, user:) }

    it "permits management" do
      policy = described_class.new(user, commitment)

      expect(%i[create update destroy complete cancel reopen].all? { |action| policy.public_send("#{action}?") }).to be(true)
    end
  end

  context "when the relationship belongs to another user" do
    let(:profile) { create(:relationship_profile) }

    it "forbids management" do
      policy = described_class.new(user, commitment)

      expect(%i[create update destroy complete cancel reopen].any? { |action| policy.public_send("#{action}?") }).to be(false)
    end
  end
end
