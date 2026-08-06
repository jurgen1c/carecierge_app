require "rails_helper"

RSpec.describe AutomationCapability do
  describe ".all" do
    it "declares the complete CAR-68 capability catalog" do
      expect(described_class.all.map(&:key)).to eq(%w[
        draft_messages
        send_reminders
        access_contacts
        access_calendar
        suggest_gifts
        contact_vendors
        send_invitations
        make_reservations
        make_purchases
        pay_deposits
        analyze_uploaded_social_content
      ])

      expect(described_class.all).to all(
        have_attributes(
          risk_level: be_in(%w[low medium high]),
          required_permissions: be_present
        )
      )
    end
  end

  describe ".fetch" do
    it "caps high-impact capabilities at approval-required modes" do
      capability = described_class.fetch(:make_purchases)

      expect(capability.risk_level).to eq("high")
      expect(capability.allowed_modes).to eq(%w[disabled ask_every_time])
    end

    it "allows low and medium risk capabilities to declare automatic execution" do
      expect(described_class.fetch(:draft_messages).allowed_modes)
        .to eq(%w[disabled ask_every_time allow_automatically])
    end

    it "rejects an unknown capability" do
      expect { described_class.fetch(:unknown) }.to raise_error(KeyError)
    end
  end
end
