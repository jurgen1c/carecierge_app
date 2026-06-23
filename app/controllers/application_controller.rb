class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def after_sign_in_path_for(_resource)
    rails_health_check_path
  end

  private

  def user_not_authorized
    respond_to do |format|
      format.html { render plain: "Forbidden", status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
