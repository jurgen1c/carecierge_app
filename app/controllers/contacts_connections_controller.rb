class ContactsConnectionsController < ApplicationController
  before_action :private_response
  rescue_from Contacts::Error, ActiveRecord::RecordInvalid, ActionController::ParameterMissing, with: :operation_failed

  def show
    authorize ContactsConnection
    @connection = current_user.contacts_connection
    @provider_available = Contacts::GoogleOauth.available?
    @contacts = @connection&.imported_contacts&.includes(:relationship_profile)&.order(:created_at, :id)
    @page = [ params[:page].to_i, 1 ].max
    @contacts = @contacts ? @contacts.offset((@page - 1) * 20).limit(21).to_a : []
    @more = @contacts.size > 20
    @contacts = @contacts.first(20)
  end

  def new
    authorize ContactsConnection
    raise Contacts::Error.new(code: "already_connected") if current_user.contacts_connection
    Contacts::Permission.check!(user: current_user)
    state = Contacts::OauthState.issue(user: current_user, session:)
    redirect_to Contacts::GoogleOauth.authorization_url(state:, redirect_uri: callback_contacts_connection_url), allow_other_host: true
  end

  def callback
    authorize ContactsConnection
    generation = Contacts::OauthState.verify(state: params[:state], user: current_user, session:)
    raise Contacts::Error.new(code: "stale") if generation == false
    raise Contacts::Error.new(code: "cancelled") if params[:error].present?
    Contacts::Connect.call(user: current_user, code: params.require(:code), redirect_uri: callback_contacts_connection_url, generation:)
    redirect_to contacts_connection_path, notice: t("contacts.notices.connected")
  end

  def refresh
    authorize ContactsConnection
    Contacts::Refresh.call(user: current_user, more: params[:more] == "1")
    redirect_to contacts_connection_path, notice: t("contacts.notices.refreshed")
  end

  def decide
    authorize ContactsConnection
    connection = current_user.contacts_connection || raise(ActiveRecord::RecordNotFound)
    contact = connection.imported_contacts.find(params[:contact_id])
    permitted = params.permit(:choice, :lock_version, :profile_id, :allow_duplicate)
    Contacts::Decide.call(contact:, actor: current_user, choice: permitted[:choice], expected_version: permitted[:lock_version],
      profile_id: permitted[:profile_id], allow_duplicate: permitted[:allow_duplicate] == "1")
    redirect_to contacts_connection_path, notice: t("contacts.notices.saved")
  end

  def destroy
    authorize ContactsConnection
    raise Contacts::Error.new(code: "cleanup_required") unless Contacts::Disconnect.call(user: current_user)
    redirect_to contacts_connection_path, notice: t("contacts.notices.disconnected")
  end

  private

  def private_response
    response.headers["Cache-Control"] = "no-store"
  end

  def operation_failed(error)
    code = error.respond_to?(:code) ? error.code : "failed"
    redirect_to contacts_connection_path, alert: t("contacts.errors.#{code}", default: t("contacts.errors.failed"))
  end
end
