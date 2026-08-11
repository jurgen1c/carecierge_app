module PrivacyVaultSession
  extend ActiveSupport::Concern

  LEASE_DURATION = PrivacyVault::Lease::DURATION
  SESSION_KEY = "privacy_vault_lease".freeze

  included do
    helper_method :privacy_vault_unlocked?, :privacy_vault_lease_expires_at
  end

  private

  def privacy_vault_unlocked?
    lease = privacy_vault_lease
    return true if lease&.active_for?(current_user.reload)

    clear_privacy_vault_lease
  end

  def unlock_privacy_vault!
    session[SESSION_KEY] = PrivacyVault::Lease.issue_for(current_user).to_session
  end

  def touch_privacy_vault_lease!
    return false unless privacy_vault_unlocked?

    session[SESSION_KEY]["last_activity_at"] = Time.current.to_i
    true
  end

  def privacy_vault_lease
    PrivacyVault::Lease.from_session(session[SESSION_KEY])
  end

  def privacy_vault_lease_expires_at
    privacy_vault_lease&.expires_at
  end

  def clear_privacy_vault_lease
    session.delete(SESSION_KEY)
    false
  end

  def require_privacy_vault_unlock
    return if touch_privacy_vault_lease!

    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: t("privacy_vaults.access_required")
  end
end
