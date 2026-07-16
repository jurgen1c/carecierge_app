module PrivacyVaultSession
  extend ActiveSupport::Concern

  LEASE_DURATION = 10.minutes
  SESSION_KEY = "privacy_vault_lease".freeze

  included do
    helper_method :privacy_vault_unlocked?, :privacy_vault_lease_expires_at
  end

  private

  def privacy_vault_unlocked?
    lease = session[SESSION_KEY]
    return false unless lease.is_a?(Hash)
    return clear_privacy_vault_lease unless lease["user_id"] == current_user.id
    return clear_privacy_vault_lease unless lease["password_fingerprint"] == privacy_vault_password_fingerprint
    return clear_privacy_vault_lease unless lease["version"] == current_user.reload.privacy_vault_lease_version

    last_activity_at = Time.zone.at(lease.fetch("last_activity_at"))
    return true if last_activity_at >= LEASE_DURATION.ago

    clear_privacy_vault_lease
  rescue KeyError, TypeError, ArgumentError
    clear_privacy_vault_lease
  end

  def unlock_privacy_vault!
    session[SESSION_KEY] = {
      "user_id" => current_user.id,
      "password_fingerprint" => privacy_vault_password_fingerprint,
      "version" => current_user.privacy_vault_lease_version,
      "last_activity_at" => Time.current.to_i
    }
  end

  def touch_privacy_vault_lease!
    return false unless privacy_vault_unlocked?

    session[SESSION_KEY]["last_activity_at"] = Time.current.to_i
    true
  end

  def privacy_vault_lease_expires_at
    last_activity_at = session.dig(SESSION_KEY, "last_activity_at")
    return if last_activity_at.blank?

    Time.zone.at(last_activity_at) + LEASE_DURATION
  rescue TypeError, ArgumentError
    nil
  end

  def clear_privacy_vault_lease
    session.delete(SESSION_KEY)
    false
  end

  def require_privacy_vault_unlock
    return if touch_privacy_vault_lease!

    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: t("privacy_vaults.access_required")
  end

  def privacy_vault_password_fingerprint
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, current_user.encrypted_password)
  end
end
