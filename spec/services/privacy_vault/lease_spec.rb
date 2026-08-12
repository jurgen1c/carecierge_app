require "rails_helper"

RSpec.describe PrivacyVault::Lease do
  it "round-trips an issued password-backed lease through session-safe data" do
    user = create(:user)
    issued_at = Time.zone.local(2026, 8, 11, 12)
    lease = described_class.issue_for(user, at: issued_at)

    restored = described_class.from_session(lease.to_session)

    expect(restored).to eq(lease)
    expect(restored).to be_active_for(user, at: issued_at + 9.minutes)
    expect(restored).not_to be_active_for(user, at: issued_at + 10.minutes + 1.second)
  end

  it "fails closed for malformed session data" do
    malformed_values = [
      nil,
      {},
      { "user_id" => "user", "password_fingerprint" => "fingerprint", "version" => 0, "last_activity_at" => "invalid" }
    ]

    expect(malformed_values.map { |value| described_class.from_session(value) }).to eq([ nil, nil, nil ])
  end
end
