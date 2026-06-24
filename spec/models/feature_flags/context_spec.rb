require "rails_helper"

RSpec.describe FeatureFlags::Context do
  describe "#value_for" do
    it "returns explicit values for every supported target kind" do
      user = build_stubbed(:user)
      account = double(id: SecureRandom.uuid)
      rollout_group = build(:rollout_group, key: "early_access")

      context = described_class.new(
        user:,
        account:,
        segment: "care_team",
        rollout_group:,
        environment: "staging"
      )

      expect(context.value_for("user")).to eq(user.id)
      expect(context.value_for("account")).to eq(account.id)
      expect(context.value_for("segment")).to eq("care_team")
      expect(context.value_for("rollout_group")).to eq("early_access")
      expect(context.value_for("environment")).to eq("staging")
      expect(context.value_for("global")).to eq("all")
      expect(context.value_for("unknown")).to be_nil
    end

    it "supports plain identifiers and blank values" do
      context = described_class.new(
        user: nil,
        account: "account-1",
        segment: "",
        rollout_group: "beta",
        environment: nil
      )

      expect(context.value_for("user")).to be_nil
      expect(context.value_for("account")).to eq("account-1")
      expect(context.value_for("segment")).to be_nil
      expect(context.value_for("rollout_group")).to eq("beta")
      expect(context.value_for("environment")).to be_nil
    end
  end
end
