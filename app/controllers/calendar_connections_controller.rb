class CalendarConnectionsController < ApplicationController
  before_action :set_connection, only: %i[update sync destroy]
  before_action :prevent_oauth_while_revocation_unresolved, only: %i[new callback]

  def show
    @connection = current_user.calendar_connection
    @credential_revocation_pending = current_user.calendar_credential_revocations.exists?
    authorize @connection || CalendarConnection
    @provider_available = CalendarConnections::GoogleOauth.available?
  end

  def new
    authorize CalendarConnection
    unless CalendarConnections::GoogleOauth.available?
      redirect_to calendar_connection_path, alert: t("calendar_connections.notices.provider_unavailable")
      return
    end

    state = CalendarConnections::OauthState.issue(user: current_user, session:)
    redirect_to CalendarConnections::GoogleOauth.authorization_url(
      state:,
      redirect_uri: callback_calendar_connection_url
    ), allow_other_host: true
  end

  def callback
    authorize CalendarConnection, :callback?
    credentials = nil
    expected_generation = CalendarConnections::OauthState.verify(state: params[:state], user: current_user, session:)
    if expected_generation == false
      redirect_to calendar_connection_path, alert: t("calendar_connections.notices.invalid_state")
      return
    end
    if params[:error].present?
      redirect_to calendar_connection_path, alert: t("calendar_connections.notices.authorization_cancelled")
      return
    end

    callback_error = nil
    cleanup_attempted = false
    cleanup_credentials = nil
    cleanup_error_code = nil
    previous_credentials_revoked = false
    connection = current_user.with_lock do
      begin
        credentials = CalendarConnections::GoogleOauth.exchange(
          code: params.require(:code),
          redirect_uri: callback_calendar_connection_url
        )
        CalendarConnection.transaction(requires_new: true) do
          CalendarConnections::SaveCredentials.call(
            user: current_user,
            credentials:,
            actor: current_user,
            expected_generation:,
            locale: I18n.locale,
            after_previous_revoke: -> { previous_credentials_revoked = true }
          )
        end
      rescue StandardError => error
        cleanup_credentials = credentials || (error.credentials if error.respond_to?(:credentials))
        cleanup_attempted = cleanup_credentials.present?
        callback_error = error
        begin
          persist_previous_revocation_failure! if error.respond_to?(:previous_revocation_failed) && error.previous_revocation_failed
          compensate_previous_revocation! if previous_credentials_revoked
        rescue StandardError => compensation_error
          callback_error = compensation_error
        ensure
          if cleanup_credentials
            begin
              cleanup_error_code = revoke_uncommitted_credentials(cleanup_credentials)
            rescue StandardError => cleanup_error
              callback_error = cleanup_error
            ensure
              credentials = nil
            end
          end
        end
        nil
      end
    end
    raise callback_error if callback_error
    CalendarSyncJob.perform_later(connection, owner_requested: true)
    redirect_to calendar_connection_path, notice: t("calendar_connections.notices.connected")
  rescue ActionController::ParameterMissing, CalendarConnections::ConnectionError => error
    code = cleanup_error_code || (error.respond_to?(:code) ? error.code : "connection_failed")
    uncommitted_credentials = credentials || (error.credentials if error.respond_to?(:credentials)) unless cleanup_attempted
    code = revoke_uncommitted_credentials(uncommitted_credentials) || code if uncommitted_credentials
    redirect_to calendar_connection_path, alert: t("calendar_connections.errors.#{code}", default: t("calendar_connections.errors.connection_failed"))
  end

  def update
    authorize @connection
    sync_types = Array(calendar_connection_params[:sync_types]) & CalendarConnection::SYNC_TYPES
    CalendarConnections::UpdateSettings.call(connection: @connection, sync_types:, actor: current_user)
    redirect_to calendar_connection_path, notice: t("calendar_connections.notices.settings_saved")
  end

  def sync
    authorize @connection, :sync?
    CalendarSyncJob.perform_later(@connection, owner_requested: true)
    redirect_to calendar_connection_path, notice: t("calendar_connections.notices.sync_requested")
  end

  def destroy
    authorize @connection
    if CalendarConnections::Disconnect.call(connection: @connection, actor: current_user)
      redirect_to calendar_connection_path, notice: t("calendar_connections.notices.disconnected")
    else
      redirect_to calendar_connection_path, alert: t("calendar_connections.notices.disconnect_failed")
    end
  end

  private

  def set_connection
    @connection = current_user.calendar_connection || raise(ActiveRecord::RecordNotFound)
  end

  def calendar_connection_params
    params.fetch(:calendar_connection, {}).permit(sync_types: [])
  end

  def prevent_oauth_while_revocation_unresolved
    if current_user.calendar_credential_revocations.exists?
      redirect_to calendar_connection_path, alert: t("calendar_connections.notices.credential_cleanup_pending")
    elsif current_user.calendar_connection&.last_error_code == "revocation_failed"
      redirect_to calendar_connection_path, alert: t("calendar_connections.notices.disconnect_failed")
    end
  end
  def revoke_uncommitted_credentials(credentials)
    CalendarConnections::GoogleOauth.revoke(credentials:)
    nil
  rescue CalendarConnections::ConnectionError => error
    CalendarConnections::StoreCredentialRevocation.call(user: current_user, credentials:, error_code: error.code)
    error.code
  end

  def compensate_previous_revocation!
    connection = CalendarConnection.lock.find_by(user_id: current_user.id)
    return unless connection

    current_user.increment!(:calendar_connection_generation)
    connection.update!(
      sync_status: "action_required",
      sync_lease_token: nil,
      sync_lease_expires_at: nil,
      resync_requested: false,
      last_error_at: Time.current,
      last_error_code: "authorization_required"
    )
    AuditEvent.record!(
      user: current_user,
      actor: current_user,
      action: "calendar.connection.revoked",
      target: current_user,
      metadata: { result: "success" }
    )
  end

  def persist_previous_revocation_failure!
    connection = CalendarConnection.lock.find_by(user_id: current_user.id)
    return unless connection

    connection.update!(
      sync_status: "failed",
      sync_lease_token: nil,
      sync_lease_expires_at: nil,
      resync_requested: false,
      last_error_at: Time.current,
      last_error_code: "revocation_failed"
    )
    AuditEvent.record!(
      user: current_user,
      actor: current_user,
      action: "calendar.connection.revocation_failed",
      target: connection,
      metadata: { result: "revocation_failed" }
    )
  end
end
