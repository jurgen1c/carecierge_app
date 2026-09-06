class VaultMfasController < ApplicationController
  include PrivacyVaultSession

  before_action :prepare_security_page

  def show
  end

  def create
    result = PrivacyVault::Enrollment.call(user: current_user, action: :start,
      session_token: enrollment_session_token, password: mfa_params[:password])
    render_enrollment_result(result)
  end

  def prove
    result = PrivacyVault::Enrollment.call(user: current_user, action: :prove,
      session_token: enrollment_session_token, code: mfa_params[:code])
    render_enrollment_result(result)
  end

  def complete
    result = PrivacyVault::Enrollment.call(user: current_user, action: :complete,
      session_token: enrollment_session_token, acknowledged: mfa_params[:acknowledged] == "1")
    if result.success
      clear_privacy_vault_lease
      session.delete(:vault_mfa_enrollment)
      redirect_to vault_mfa_path, notice: t("vault_mfa.enrolled"), status: :see_other
    else
      render_enrollment_result(result)
    end
  end

  def regenerate
    manage(:regenerate)
  end

  def destroy
    manage(:disable)
  end

  def reset_password
    current_user.with_lock { current_user.increment!(:privacy_vault_lease_version) }
    clear_privacy_vault_lease
    session.delete(:vault_mfa_enrollment)
    sign_out(current_user)
    redirect_to new_user_password_path, status: :see_other
  end

  private

  def prepare_security_page
    @credential = current_user.vault_mfa_credential || current_user.build_vault_mfa_credential
    authorize @credential, :update?
    response.headers["Cache-Control"] = "no-store"
    response.headers["Referrer-Policy"] = "no-referrer"
  end

  def enrollment_session_token
    session[:vault_mfa_enrollment] ||= SecureRandom.hex(32)
  end

  def mfa_params
    params.fetch(:vault_mfa, ActionController::Parameters.new).permit(:password, :code, :acknowledged)
  end

  def render_enrollment_result(result)
    @credential = current_user.reload.vault_mfa_credential
    @secret = result.secret
    @enrollment_pending = @credential.enrollment_active_for?(session[:vault_mfa_enrollment]) && @credential.enrollment_verified_at.nil?
    @recovery_codes = result.recovery_codes
    @enrollment_codes = @recovery_codes.present?
    @error = t("vault_mfa.errors.#{result.error}") unless result.success
    render :show, status: result.success ? :ok : :unprocessable_content
  end

  def manage(action)
    result = PrivacyVault::ManageMfa.call(user: current_user, action:,
      password: mfa_params[:password], code: mfa_params[:code])
    clear_privacy_vault_lease
    @credential = current_user.reload.vault_mfa_credential || current_user.build_vault_mfa_credential
    if result.success && action == :disable
      redirect_to vault_mfa_path, notice: t("vault_mfa.disabled"), status: :see_other
    else
      @recovery_codes = result.recovery_codes
      @error = t("vault_mfa.errors.#{result.error}") unless result.success
      render :show, status: result.success ? :ok : :unprocessable_content
    end
  end
end
