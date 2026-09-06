class VaultMfaCredential < ApplicationRecord
  RECOVERY_CODE_COUNT = 10
  ATTEMPT_LIMIT = 5
  ATTEMPT_WINDOW = 5.minutes
  ENROLLMENT_DURATION = 10.minutes

  belongs_to :user
  encrypts :totp_secret

  validates :user_id, uniqueness: true
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :totp_secret, presence: true, if: :enabled?

  def enabled?
    enabled_at.present?
  end

  def rate_limited?
    attempt_window_at.present? && attempt_window_at > ATTEMPT_WINDOW.ago && attempts >= ATTEMPT_LIMIT
  end

  def record_failure!
    if attempt_window_at.nil? || attempt_window_at <= ATTEMPT_WINDOW.ago
      self.attempt_window_at = Time.current
      self.attempts = 0
    end
    self.attempts += 1
    save!
  end

  # Call consumption methods under the owning user lock to serialize all sessions.
  def consume_totp!(code)
    return false unless totp_secret.present? && code.is_a?(String) && code.match?(/\A\d{6}\z/)

    timestamp = ROTP::TOTP.new(totp_secret).verify(code, drift_behind: 30, after: last_totp_at, at: Time.current)
    return false unless timestamp

    update!(last_totp_at: timestamp)
    true
  end

  def consume_recovery_code!(code)
    return false unless code.is_a?(String) && code.match?(/\A[0-9a-f]{8}-[0-9a-f]{8}\z/)

    index = recovery_code_digests.index { |digest| BCrypt::Password.new(digest).is_password?(code) }
    return false unless index

    update!(recovery_code_digests: recovery_code_digests.reject.with_index { |_, i| i == index })
    true
  end

  def replace_recovery_codes!
    Array.new(RECOVERY_CODE_COUNT) { "#{SecureRandom.hex(4)}-#{SecureRandom.hex(4)}" }.tap do |codes|
      self.recovery_code_digests = codes.map { |code| BCrypt::Password.create(code, cost: Devise.stretches).to_s }
    end
  end

  def enrollment_active_for?(session_token)
    !enabled? && enrollment_expires_at.present? && enrollment_expires_at > Time.current &&
      enrollment_session_digest.present? && session_token.present? &&
      ActiveSupport::SecurityUtils.secure_compare(enrollment_session_digest, Digest::SHA256.hexdigest(session_token)) &&
      ActiveSupport::SecurityUtils.secure_compare(enrollment_password_fingerprint.to_s, enrollment_fingerprint)
  end

  def enrollment_fingerprint
    Digest::SHA256.hexdigest("#{PrivacyVault::Lease.password_fingerprint_for(user)}:#{user.privacy_vault_lease_version}")
  end

  def clear_enrollment
    self.enrollment_expires_at = nil
    self.enrollment_session_digest = nil
    self.enrollment_password_fingerprint = nil
    self.enrollment_verified_at = nil
  end
end
