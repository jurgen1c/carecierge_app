# == Schema Information
#
# Table name: feature_flags
# Database name: primary
#
#  id          :uuid             not null, primary key
#  description :text
#  enabled     :boolean          default(FALSE), not null
#  key         :string           not null
#  metadata    :jsonb            not null
#  name        :string           not null
#  retired_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_feature_flags_on_key         (key) UNIQUE
#  index_feature_flags_on_retired_at  (retired_at)
#
require "rails_helper"

RSpec.describe FeatureFlag, type: :model do
  describe ".enabled?" do
    it "uses the flag default when no targeted assignment matches" do
      create(:feature_flag, key: "birthday_concierge", enabled: true)

      expect(described_class.enabled?("birthday_concierge", environment: "production")).to be(true)
      expect(described_class.enabled?("unknown_flag", environment: "production")).to be(false)
    end

    it "allows an environment assignment to enable a disabled flag" do
      flag = create(:feature_flag, key: "calendar_integration", enabled: false)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "environment", target_value: "staging", enabled: true)

      expect(described_class.enabled?("calendar_integration", environment: "staging")).to be(true)
      expect(described_class.enabled?("calendar_integration", environment: "production")).to be(false)
    end

    it "applies deterministic assignment precedence from user to global" do
      user = create(:user)
      flag = create(:feature_flag, key: "ai_memory_extraction", enabled: false)

      create(:feature_flag_assignment, feature_flag: flag, target_kind: "global", target_value: "all", enabled: false)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "environment", target_value: "test", enabled: true)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "rollout_group", target_value: "early_access", enabled: false)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "segment", target_value: "care_team", enabled: true)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "user", target_value: user.id, enabled: false)

      expect(
        described_class.enabled?(
          "ai_memory_extraction",
          user:,
          segment: "care_team",
          rollout_group: "early_access",
          environment: "test"
        )
      ).to be(false)
    end

    it "keeps retired flags disabled even when assignments match" do
      flag = create(:feature_flag, key: "marketplace", enabled: true, retired_at: 1.day.ago)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "environment", target_value: "test", enabled: true)

      expect(described_class.enabled?("marketplace", environment: "test")).to be(false)
    end
  end

  describe ".retired" do
    it "returns retired flags for cleanup discovery" do
      retired = create(:feature_flag, key: "old_social_helper", retired_at: 1.day.ago)
      create(:feature_flag, key: "active_social_helper", retired_at: nil)

      expect(described_class.retired).to contain_exactly(retired)
    end
  end
end
