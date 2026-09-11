class ApplicationController < ActionController::Base
  include Pagy::Method
  include Pundit::Authorization

  around_action :with_request_locale
  before_action :authenticate_user!, unless: :devise_controller?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  def after_sign_in_path_for(resource)
    return onboarding_path if resource.respond_to?(:onboarding_pending?) && resource.onboarding_pending?

    restored_sign_in_destination(resource) || concierge_conversations_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def restored_sign_in_destination(resource)
    destination = url_from(stored_location_for(resource))
    return unless destination

    route = Rails.application.routes.recognize_path(destination, method: :get)
    if route[:controller] == "concierge_conversations" && route[:action] == "transcript"
      concierge_conversation_path(route.fetch(:id))
    else
      destination
    end
  rescue ActionController::RoutingError
    destination
  end

  def with_request_locale(&action)
    previous_pagy_locale = Pagy::I18n.locale
    available = I18n.available_locales.map(&:to_s)
    if params.key?(:locale) && request.headers["X-Sec-Purpose"] != "prefetch"
      requested = params[:locale]
      session[:locale] = available.include?(requested) ? requested : I18n.default_locale.to_s
    end
    locale = session[:locale].presence_in(available) || I18n.locale
    I18n.with_locale(locale) do
      Pagy::I18n.locale = I18n.locale
      action.call
    end
  ensure
    Pagy::I18n.locale = previous_pagy_locale
  end

  def user_not_authorized
    respond_to do |format|
      format.html { render plain: "Forbidden", status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
