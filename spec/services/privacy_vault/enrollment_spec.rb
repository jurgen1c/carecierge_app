require "rails_helper"

RSpec.describe PrivacyVault::Enrollment do
  let(:password) { "known-password123" }
  let(:user) { create(:user, password:) }
  let(:session_token) { SecureRandom.hex(32) }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 5, 12)) { example.run } }

  def start_enrollment
    described_class.call(user:, action: :start, session_token:, password:)
  end

  it "rejects another session, an expired enrollment, and a changed password" do
    secret = start_enrollment.secret
    code = ROTP::TOTP.new(secret).now
    expect(described_class.call(user:, action: :prove, session_token: "different", code:).error).to eq(:expired)
    Timecop.travel(11.minutes.from_now)
    expect(described_class.call(user:, action: :prove, session_token:, code: ROTP::TOTP.new(secret).now).error).to eq(:expired)
    secret = start_enrollment.secret
    user.update!(password: "replacement123", password_confirmation: "replacement123")
    expect(described_class.call(user:, action: :prove, session_token:, code: ROTP::TOTP.new(secret).now).error).to eq(:expired)
  end

  it "rejects a second proof without showing codes again, and restarting discards the pending key" do
    secret = start_enrollment.secret
    code = ROTP::TOTP.new(secret).now
    result = described_class.call(user:, action: :prove, session_token:, code:)
    expect(result.recovery_codes.size).to eq(10)
    expect(described_class.call(user:, action: :prove, session_token:, code:).recovery_codes).to be_nil
    replacement = start_enrollment.secret
    expect(replacement).not_to eq(secret)
    expect(user.reload.vault_mfa_credential.recovery_code_digests).to be_empty
    expect(described_class.call(user:, action: :complete, session_token:, acknowledged: true).success).to be(false)
  end

  it "bounds failed enrollment proof attempts without permitting password-only reset of the limit" do
    start_enrollment
    5.times { described_class.call(user:, action: :prove, session_token:, code: "invalid") }
    expect(described_class.call(user:, action: :prove, session_token:, code: "123456").error).to eq(:rate_limited)
    expect(start_enrollment.error).to eq(:rate_limited)
  end

  it "audits rejected proof attempts for expired sessions and account limits" do
    start_enrollment
    expect {
      described_class.call(user:, action: :prove, session_token: "different", code: "123456")
    }.to change { user.audit_events.where(action: "privacy_vault.mfa_verification_failed").count }.by(1)
    credential = user.reload.vault_mfa_credential
    credential.update!(attempts: 5, attempt_window_at: Time.current)
    expect {
      described_class.call(user:, action: :prove, session_token:, code: "123456")
    }.to change { user.audit_events.where(action: "privacy_vault.mfa_verification_failed").count }.by(1)
  end

  it "revokes existing leases only after verified and acknowledged enrollment completes" do
    lease = PrivacyVault::Lease.issue_for(user)
    secret = start_enrollment.secret
    described_class.call(user:, action: :prove, session_token:, code: ROTP::TOTP.new(secret).now)
    expect(lease).to be_active_for(user.reload)
    described_class.call(user:, action: :complete, session_token:, acknowledged: true)
    expect(lease).not_to be_active_for(user.reload)
  end
end
