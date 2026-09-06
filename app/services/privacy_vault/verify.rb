# Application-layer verification. Call with the owning user locked and freshly loaded.
class PrivacyVault::Verify
  def self.call(user:, password:, code: nil, second_factor: :optional, credential: user.vault_mfa_credential)
    credential = nil if second_factor == :optional && !credential&.enabled?
    if credential&.rate_limited?
      fail_verification(user, credential, :rate_limited)
    elsif !password.is_a?(String) || !user.valid_password?(password)
      fail_verification(user, credential, :invalid)
    elsif second_factor == :password || (second_factor == :optional && !credential&.enabled?)
      :password
    elsif credential&.consume_totp!(code)
      audit_safely(user, "mfa_verified")
      :totp
    elsif second_factor != :totp && credential&.enabled? && credential.consume_recovery_code!(code)
      audit_safely(user, "mfa_verified")
      audit_safely(user, "recovery_used")
      :recovery
    else
      fail_verification(user, credential, :invalid)
    end
  end

  def self.audit(user, event)
    AuditEvent.record!(user:, actor: user, action: "privacy_vault.#{event}")
  end

  def self.audit_safely(user, event)
    AuditEvent.transaction(requires_new: true) { audit(user, event) }
  rescue ActiveRecord::ActiveRecordError => error
    Rails.error.report(error, handled: true, context: { component: "vault_mfa_audit", event: })
    nil
  end

  def self.fail_verification(user, credential, result)
    credential&.record_failure! unless result == :rate_limited
    user.increment!(:privacy_vault_lease_version)
    audit_safely(user, "mfa_verification_failed") if credential
    result
  end
  private_class_method :fail_verification
end
