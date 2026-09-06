class PrivacyVault::Enrollment
  Result = Data.define(:success, :error, :secret, :recovery_codes)

  def self.call(user:, action:, session_token:, password: nil, code: nil, acknowledged: false)
    user.with_lock do
      credential = user.vault_mfa_credential || user.create_vault_mfa_credential!
      return failure(:already_enabled) if credential.enabled?

      case action
      when :start
        outcome = PrivacyVault::Verify.call(user:, password:, credential:, second_factor: :password)
        return failure(outcome) unless outcome == :password

        credential.clear_enrollment
        credential.update!(totp_secret: ROTP::Base32.random, last_totp_at: nil, recovery_code_digests: [],
          enrollment_expires_at: VaultMfaCredential::ENROLLMENT_DURATION.from_now,
          enrollment_session_digest: Digest::SHA256.hexdigest(session_token),
          enrollment_password_fingerprint: credential.enrollment_fingerprint)
        Result.new(success: true, error: nil, secret: credential.totp_secret, recovery_codes: nil)
      when :prove
        return failure(:expired, user:) unless credential.enrollment_active_for?(session_token) && credential.enrollment_verified_at.nil?
        return failure(:rate_limited, user:) if credential.rate_limited?

        unless credential.consume_totp!(code)
          credential.record_failure!
          PrivacyVault::Verify.audit_safely(user, "mfa_verification_failed")
          return failure(:invalid)
        end
        codes = credential.replace_recovery_codes!
        credential.update!(enrollment_verified_at: Time.current)
        PrivacyVault::Verify.audit_safely(user, "mfa_verified")
        Result.new(success: true, error: nil, secret: nil, recovery_codes: codes)
      when :complete
        return failure(:expired) unless credential.enrollment_active_for?(session_token) && credential.enrollment_verified_at.present?
        return failure(:acknowledgement_required) unless acknowledged

        credential.clear_enrollment
        credential.update!(enabled_at: Time.current)
        user.increment!(:privacy_vault_lease_version)
        PrivacyVault::Verify.audit(user, "mfa_enrolled")
        Result.new(success: true, error: nil, secret: nil, recovery_codes: nil)
      else
        failure(:invalid)
      end
    end
  end

  def self.failure(error, user: nil)
    PrivacyVault::Verify.audit_safely(user, "mfa_verification_failed") if user
    Result.new(success: false, error:, secret: nil, recovery_codes: nil)
  end
  private_class_method :failure
end
