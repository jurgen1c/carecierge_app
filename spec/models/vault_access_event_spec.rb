require "rails_helper"

RSpec.describe VaultAccessEvent, type: :model do
  describe ".record_safely" do
    it "reports persistence failures without exposing record attributes" do
      error = ActiveRecord::RecordInvalid.new(described_class.new)
      allow(described_class).to receive(:record!).and_raise(error)
      allow(Rails.error).to receive(:report)

      result = described_class.record_safely(
        event_type: "viewed",
        user: build(:user),
        relationship_profile: build(:relationship_profile)
      )

      expect(result).to be_nil
      expect(Rails.error).to have_received(:report).with(
        error,
        handled: true,
        context: { component: "privacy_vault_access_audit", event_type: "viewed" }
      )
    end
  end
end
