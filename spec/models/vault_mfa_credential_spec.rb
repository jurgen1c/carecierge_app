require "rails_helper"

RSpec.describe VaultMfaCredential, type: :model do
  let(:credential) { create(:user).create_vault_mfa_credential!(totp_secret: ROTP::Base32.random) }

  it "encrypts its secret and stores individually salted recovery digests" do
    codes = credential.replace_recovery_codes!
    credential.save!
    expect(credential.attributes_before_type_cast["totp_secret"]).not_to include(credential.totp_secret)
    expect(codes.length).to eq(10)
    expect(codes.uniq.length).to eq(10)
    expect(credential.recovery_code_digests.uniq.length).to eq(10)
    codes.each { |code| expect(credential.attributes.to_s).not_to include(code) }
  end

  it "consumes recovery codes only once and rejects malformed codes" do
    code = credential.replace_recovery_codes!.first
    credential.save!
    expect(credential.consume_recovery_code!("invalid")).to be(false)
    expect(credential.consume_recovery_code!(code)).to be(true)
    expect(credential.consume_recovery_code!(code)).to be(false)
  end

  it "rejects expired and replayed TOTP with a bounded 30 second previous window" do
    Timecop.freeze(Time.zone.local(2026, 9, 5, 12)) do
      totp = ROTP::TOTP.new(credential.totp_secret)
      expect(credential.consume_totp!(totp.at(61.seconds.ago))).to be(false)
      expect(credential.consume_totp!(totp.at(31.seconds.from_now))).to be(false)
      expect(credential.consume_totp!(totp.at(30.seconds.ago))).to be(true)
      expect(credential.consume_totp!(totp.at(30.seconds.ago))).to be(false)
      expect(credential.consume_totp!(totp.now)).to be(true)
      expect(credential.consume_totp!(totp.now)).to be(false)
    end
  end
end
