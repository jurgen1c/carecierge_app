class Users::SessionsController < Devise::SessionsController
  def destroy
    current_user&.with_lock { current_user.increment!(:privacy_vault_lease_version) }
    session.delete(:vault_mfa_enrollment)
    super
  end
end
