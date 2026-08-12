class PrivacyVault::Lease < Data.define(:user_id, :password_fingerprint, :version, :last_activity_at)
  DURATION = 10.minutes

  def self.issue_for(user, at: Time.current)
    new(
      user_id: user.id,
      password_fingerprint: password_fingerprint_for(user),
      version: user.privacy_vault_lease_version,
      last_activity_at: at
    )
  end

  def self.from_session(value)
    return unless value.is_a?(Hash)

    new(
      user_id: value.fetch("user_id"),
      password_fingerprint: value.fetch("password_fingerprint"),
      version: value.fetch("version"),
      last_activity_at: Time.zone.at(value.fetch("last_activity_at"))
    )
  rescue KeyError, TypeError, ArgumentError
    nil
  end

  def self.password_fingerprint_for(user)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, user.encrypted_password)
  end

  def active_for?(user, at: Time.current)
    user_id == user.id &&
      version == user.privacy_vault_lease_version &&
      password_fingerprint_matches?(user) &&
      last_activity_at >= at - DURATION
  end

  def expires_at
    last_activity_at + DURATION
  end

  def to_session
    {
      "user_id" => user_id,
      "password_fingerprint" => password_fingerprint,
      "version" => version,
      "last_activity_at" => last_activity_at.to_i
    }
  end

  private

  def password_fingerprint_matches?(user)
    return false unless password_fingerprint.is_a?(String)

    ActiveSupport::SecurityUtils.secure_compare(
      password_fingerprint,
      self.class.password_fingerprint_for(user)
    )
  end
end
