class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    @user = User.from_google_oauth(request.env.fetch("omniauth.auth"))

    sign_in_and_redirect @user, event: :authentication
    set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
  end

  def failure
    redirect_to new_user_session_path, alert: t("devise.omniauth_callbacks.failure", kind: "Google", reason: failure_message)
  end
end
