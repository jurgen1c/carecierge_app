require "rails_helper"

RSpec.describe PrivacyVault::Unlock do
  let(:password) { "known-password123" }
  let(:user) { create(:user, password:) }

  it "preserves password-only unlocks" do
    expect(described_class.call(user:, password:).lease).to be_active_for(user)
    expect(described_class.call(user:, password: "wrong").lease).to be_nil
  end

  it "requires both factors and rejects TOTP replay" do
    Timecop.freeze(Time.zone.local(2026, 9, 5, 12)) do
      credential = user.create_vault_mfa_credential!(totp_secret: ROTP::Base32.random, enabled_at: Time.current)
      code = ROTP::TOTP.new(credential.totp_secret).now
      expect(described_class.call(user:, password: "wrong", code:).lease).to be_nil
      expect(described_class.call(user:, password:).lease).to be_nil
      expect(described_class.call(user:, password:, code:).lease).to be_active_for(user.reload)
      expect(described_class.call(user:, password:, code:).lease).to be_nil
    end
  end
end

RSpec.describe "Vault lease security changes" do
  it "revokes leases on identity changes even from a stale User instance" do
    user = create(:user)
    stale = User.find(user.id)
    user.increment!(:privacy_vault_lease_version)
    lease = PrivacyVault::Lease.issue_for(user)
    stale.update!(unconfirmed_email: "new@example.com")
    expect(stale.privacy_vault_lease_version).to eq(user.privacy_vault_lease_version + 1)
    expect(lease).not_to be_active_for(user.reload)
  end

  it "does not roll back revocation or attempt counters when verification auditing fails" do
    user = create(:user, password: "known-password123")
    create(:vault_mfa_credential, user:)
    lease = PrivacyVault::Lease.issue_for(user)
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(AuditEvent.new))
    result = PrivacyVault::Unlock.call(user:, password: "wrong", code: "invalid")
    expect(result.lease).to be_nil
    expect(lease).not_to be_active_for(user.reload)
    expect(user.vault_mfa_credential.attempts).to eq(1)
  end
end
