class PrivacyVault::ManageMfa
  Result = Data.define(:success, :error, :recovery_codes)

  def self.call(user:, action:, password:, code:)
    user.with_lock do
      credential = user.vault_mfa_credential
      return Result.new(success: false, error: :not_enabled, recovery_codes: nil) unless credential&.enabled?

      factor = action == :regenerate ? :totp : :required
      outcome = PrivacyVault::Verify.call(user:, password:, code:, second_factor: factor, credential:)
      return Result.new(success: false, error: outcome, recovery_codes: nil) unless outcome.in?(%i[totp recovery])

      codes = nil
      if action == :regenerate
        codes = credential.replace_recovery_codes!
        credential.save!
        PrivacyVault::Verify.audit(user, "recovery_regenerated")
      elsif action == :disable
        credential.update!(enabled_at: nil, totp_secret: nil, recovery_code_digests: [], last_totp_at: nil)
        PrivacyVault::Verify.audit(user, "mfa_disabled")
      else
        raise ArgumentError, "Unknown vault MFA operation"
      end
      user.increment!(:privacy_vault_lease_version)
      Result.new(success: true, error: nil, recovery_codes: codes)
    end
  end
end
