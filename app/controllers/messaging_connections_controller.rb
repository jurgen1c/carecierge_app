class MessagingConnectionsController < ApplicationController
  before_action :private_response
  rate_limit to: 10, within: 1.minute, by: -> { current_user.id }, only: %i[search import draft]
  rescue_from Messaging::Error, MessageDrafts::GenerationError, ActiveRecord::RecordInvalid,
    ActionController::ParameterMissing, with: :operation_failed

  def show
    authorize MessagingConnection
    load_workspace
  end

  def connect
    authorize MessagingConnection
    raise Messaging::Error.new(code: "permission_required") unless params[:approved] == "1"
    raise Messaging::Error.new(code: "already_connected") if current_user.messaging_connection
    Messaging::Permission.check!(user: current_user)
    state = Messaging::OauthState.issue(user: current_user, session:)
    redirect_to Messaging::GoogleOauth.authorization_url(state:, redirect_uri: callback_messaging_connection_url), allow_other_host: true
  end

  def callback
    authorize MessagingConnection
    generation = Messaging::OauthState.verify(state: params[:state], user: current_user, session:)
    raise Messaging::Error.new(code: "stale") if generation == false
    raise Messaging::Error.new(code: "cancelled") if params[:error].present?
    Messaging::Connect.call(user: current_user, code: params.require(:code), redirect_uri: callback_messaging_connection_url, generation:)
    redirect_to messaging_connection_path, notice: t("messaging.notices.connected")
  end

  def search
    authorize MessagingConnection
    @results = Messaging::Access.call(user: current_user) do |connection|
      Messaging::Google.new(connection:).search(query: params[:messaging_query])
    end
    load_workspace
    render :show
  end

  def import
    authorize MessagingConnection
    Messaging::Import.call(user: current_user, external_id: params[:external_id], approved: params[:approved] == "1")
    redirect_to messaging_connection_path, notice: t("messaging.notices.imported")
  end

  def draft
    authorize MessagingConnection
    Messaging::Draft.call(user: current_user, context_id: params[:context_id], expected_version: params[:lock_version], approved: params[:approved] == "1")
    redirect_to messaging_connection_path, notice: t("messaging.notices.drafted")
  end

  def edit_draft
    authorize MessagingConnection
    Messaging::EditDraft.call(user: current_user, context_id: params[:context_id], content: params[:reply_draft], expected_version: params[:lock_version])
    redirect_to messaging_connection_path, notice: t("messaging.notices.saved")
  end

  def delete_context
    authorize MessagingConnection
    Messaging::DeleteContext.call(user: current_user, context_id: params[:context_id])
    redirect_to messaging_connection_path, notice: t("messaging.notices.deleted")
  end

  def destroy
    authorize MessagingConnection
    raise Messaging::Error.new(code: "cleanup_required") unless Messaging::Disconnect.call(user: current_user)
    redirect_to messaging_connection_path, notice: t("messaging.notices.disconnected")
  end

  private

  def load_workspace
    @connection = current_user.messaging_connection
    @provider_available = Messaging::GoogleOauth.available?
    @page = [ [ params[:page].to_i, 1 ].max, 100_000 ].min
    @contexts = @connection&.imported_message_contexts&.order(created_at: :desc, id: :desc)&.offset((@page - 1) * 20)&.limit(21)&.to_a || []
    @more = @contexts.size > 20
    @contexts = @contexts.first(20)
    @results ||= nil
  end

  def private_response
    response.headers["Cache-Control"] = "no-store"
  end

  def operation_failed(error)
    code = error.respond_to?(:code) ? error.code : "failed"
    redirect_to messaging_connection_path, alert: t("messaging.errors.#{code}", default: t("messaging.errors.failed"))
  end
end
