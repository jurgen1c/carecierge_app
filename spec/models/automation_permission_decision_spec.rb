require "rails_helper"

RSpec.describe AutomationPermissionDecision do
  describe "#permits_execution?" do
    it "allows an ordinary capability configured for automatic execution" do
      decision = described_class.new(
        capability: AutomationCapability.fetch(:draft_messages),
        mode: "allow_automatically"
      )

      expect(decision).to be_enabled
      expect(decision).not_to be_approval_required
      expect(decision.permits_execution?).to be(true)
    end

    it "requires explicit approval for ask-every-time permissions" do
      decision = described_class.new(
        capability: AutomationCapability.fetch(:make_reservations),
        mode: "ask_every_time"
      )

      expect(decision).to be_approval_required
      expect(decision.permits_execution?).to be(false)
      expect(decision.permits_execution?(explicitly_approved: true)).to be(true)
    end

    it "rejects truthy non-boolean approval values" do
      decision = described_class.new(
        capability: AutomationCapability.fetch(:make_reservations),
        mode: "ask_every_time"
      )

      expect(decision.permits_execution?(explicitly_approved: "false")).to be(false)
      expect(decision.permits_execution?(explicitly_approved: "1")).to be(false)
    end

    it "fails closed for high-impact capabilities even if persisted data claims automatic execution" do
      decision = described_class.new(
        capability: AutomationCapability.fetch(:make_purchases),
        mode: "allow_automatically"
      )

      expect(decision).to be_approval_required
      expect(decision.permits_execution?).to be(false)
      expect(decision.permits_execution?(explicitly_approved: true)).to be(true)
    end

    it "never permits disabled capabilities, even with explicit approval" do
      decision = described_class.new(
        capability: AutomationCapability.fetch(:send_reminders),
        mode: "disabled"
      )

      expect(decision).not_to be_enabled
      expect(decision.permits_execution?(explicitly_approved: true)).to be(false)
    end
  end
end
