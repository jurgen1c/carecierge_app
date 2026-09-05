require "rails_helper"

RSpec.describe "Calendar connections", type: :request do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_CALENDAR_CLIENT_ID").and_return("calendar-client")
    allow(ENV).to receive(:[]).with("GOOGLE_CALENDAR_CLIENT_SECRET").and_return("calendar-secret")
  end

  it "requires authentication" do
    get calendar_connection_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders a localized owner-scoped integration surface" do
    user = create(:user)
    create(:calendar_connection, user:)
    create(:calendar_connection)
    sign_in user

    I18n.with_locale(:es) { get calendar_connection_path }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Integraciones de calendario", "Google Calendar", "Qué sincronizar")
    expect(response.body).not_to include("access-token", "refresh-token")
  end

  it "begins Google authorization with owner-bound state" do
    user = create(:user)
    sign_in user
    allow(CalendarConnections::OauthState).to receive(:issue).with(user:, session: kind_of(ActionDispatch::Request::Session)).and_return("signed-state")

    get new_calendar_connection_path

    expect(response).to redirect_to(%r{\Ahttps://accounts\.google\.com/o/oauth2/v2/auth\?})
    expect(response.location).to include("state=signed-state")
  end

  it "does not start or complete OAuth while revocation is unresolved" do
    connection = create(:calendar_connection, sync_status: "failed", last_error_code: "revocation_failed")
    sign_in connection.user
    allow(CalendarConnections::OauthState).to receive(:issue)
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(connection.user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange)

    get new_calendar_connection_path

    expect(response).to redirect_to(calendar_connection_path)
    expect(flash[:alert]).to eq("We could not revoke Google Calendar access. Try disconnecting again.")
    expect(CalendarConnections::OauthState).not_to have_received(:issue)

    get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }

    expect(response).to redirect_to(calendar_connection_path)
    expect(flash[:alert]).to eq("We could not revoke Google Calendar access. Try disconnecting again.")
    expect(CalendarConnections::GoogleOauth).not_to have_received(:exchange)
  end

  it "stores only a valid callback for the signed-in owner and queues the first sync" do
    user = create(:user)
    sign_in user
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "new-access",
      refresh_token: "new-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_return(credentials)

    expect do
      I18n.with_locale(:es) do
        get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
      end
    end.to change { CalendarConnection.where(user:).count }.by(1)
      .and have_enqueued_job(CalendarSyncJob)

    expect(response).to redirect_to(calendar_connection_path)
    expect(user.calendar_connection.access_token).to eq("new-access")
    expect(user.calendar_connection.locale).to eq("es")
  end


  it "does not start OAuth while callback credential cleanup is pending" do
    pending = create(:calendar_credential_revocation)
    sign_in pending.user
    allow(CalendarConnections::OauthState).to receive(:issue)

    get new_calendar_connection_path

    expect(response).to redirect_to(calendar_connection_path)
    expect(flash[:alert]).to eq("Calendar access cleanup is still in progress. Carecierge will retry before another connection can start.")
    expect(CalendarConnections::OauthState).not_to have_received(:issue)
  end

  it "shows pending callback cleanup without a dead connect control" do
    pending = create(:calendar_credential_revocation)
    sign_in pending.user

    get calendar_connection_path

    expect(response.body).to include("Calendar access cleanup is still in progress")
    expect(response.body).not_to include(%(href="#{new_calendar_connection_path}"))
  end

  it "does not restore a connection when disconnect finishes during token exchange" do
    connection = create(:calendar_connection)
    user = connection.user
    sign_in user
    generation = user.calendar_connection_generation
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(generation)
    provider = instance_double(CalendarProviders::Google, revoke: true)
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "stale-access",
      refresh_token: "stale-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::GoogleOauth).to receive(:exchange) do
      CalendarConnections::Disconnect.call(connection:, actor: user)
      credentials
    end
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.not_to have_enqueued_job(CalendarSyncJob)

    expect(response).to redirect_to(calendar_connection_path)
    expect(user.reload.calendar_connection).to be_nil
    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
  end

  it "keeps exchanged credentials recoverable when stale callback revocation fails" do
    connection = create(:calendar_connection)
    user = connection.user
    sign_in user
    generation = user.calendar_connection_generation
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "orphan-access",
      refresh_token: "orphan-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange) do
      connection.update!(sync_status: "failed", last_error_code: "revocation_failed")
      credentials
    end
    allow(CalendarConnections::GoogleOauth).to receive(:revoke)
      .with(credentials:)
      .and_raise(CalendarConnections::ConnectionError.new(code: "provider_unavailable"))

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.to change { CalendarCredentialRevocation.where(user:).count }.by(1)
      .and have_enqueued_job(CalendarCredentialRevocationJob)

    pending = CalendarCredentialRevocation.find_by!(user:)
    expect(pending).to have_attributes(access_token: "orphan-access", refresh_token: "orphan-refresh")
    expect(response).to redirect_to(calendar_connection_path)
  end

  it "revokes live credentials returned by an incomplete token exchange" do
    user = create(:user)
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "orphan-access",
      refresh_token: nil,
      expires_at: nil,
      scopes: [ "profile" ]
    )
    error = CalendarConnections::ConnectionError.new(
      code: "calendar_authorization_incomplete",
      credentials:
    )
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_raise(error)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)

    get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }

    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
    expect(response).to redirect_to(calendar_connection_path)
  end

  it "retains access-only callback credentials when immediate cleanup fails" do
    user = create(:user)
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "orphan-access",
      refresh_token: nil,
      expires_at: nil,
      scopes: [ "profile" ]
    )
    error = CalendarConnections::ConnectionError.new(
      code: "calendar_authorization_incomplete",
      credentials:
    )
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_raise(error)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke)
      .with(credentials:)
      .and_raise(CalendarConnections::ConnectionError.new(code: "provider_unavailable"))

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.to change { CalendarCredentialRevocation.where(user:).count }.by(1)

    expect(user.calendar_credential_revocations.last).to have_attributes(
      access_token: "orphan-access",
      refresh_token: nil
    )
  end

  it "finishes callback credential cleanup before releasing the owner lock" do
    user = create(:user)
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "orphan-access",
      refresh_token: nil,
      expires_at: nil,
      scopes: [ "profile" ]
    )
    error = CalendarConnections::ConnectionError.new(
      code: "calendar_authorization_incomplete",
      credentials:
    )
    lock_depth = 0
    owner_lock_clauses = []
    allow_any_instance_of(User).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      owner_lock_clauses << args.first
      original.call(*args) do
        lock_depth += 1
        block.call
      ensure
        lock_depth -= 1
      end
    end
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_raise(error)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:) do
      expect(lock_depth).to be_positive
      raise CalendarConnections::ConnectionError.new(code: "provider_unavailable")
    end

    get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }

    expect(user.calendar_credential_revocations.reload).to be_one
    expect(owner_lock_clauses).to all(eq("FOR NO KEY UPDATE"))
  end

  it "rolls back saved credentials before cleaning up a later persistence failure" do
    user = create(:user)
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "uncommitted-access",
      refresh_token: "uncommitted-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)
    allow(AuditEvent).to receive(:record!).and_wrap_original do |original, **attributes|
      raise ActiveRecord::ConnectionNotEstablished if attributes[:action] == "calendar.connection.created"

      original.call(**attributes)
    end

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.to raise_error(ActiveRecord::ConnectionNotEstablished)

    expect(user.reload.calendar_connection).to be_nil
    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
  end

  it "marks prior credentials revoked when a replacement fails after revocation" do
    connection = create(:calendar_connection, sync_status: "action_required", last_error_code: "authorization_required")
    user = connection.user
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "replacement-access",
      refresh_token: "replacement-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    provider = instance_double(CalendarProviders::Google, revoke: true)
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)
    allow(AuditEvent).to receive(:record!).and_wrap_original do |original, **attributes|
      raise ActiveRecord::ConnectionNotEstablished if attributes[:action] == "calendar.connection.created"

      original.call(**attributes)
    end

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.to raise_error(ActiveRecord::ConnectionNotEstablished)

    expect(provider).to have_received(:revoke)
    expect(connection.reload).to have_attributes(
      access_token: "access-token",
      sync_status: "action_required",
      last_error_code: "authorization_required"
    )
    expect(user.reload.calendar_connection_generation).to eq(1)
    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
  end

  it "blocks another authorization after prior credential revocation fails" do
    connection = create(:calendar_connection, sync_status: "action_required", last_error_code: "authorization_required")
    user = connection.user
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "replacement-access",
      refresh_token: "replacement-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    provider = instance_double(CalendarProviders::Google)
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
    allow(provider).to receive(:revoke)
      .and_raise(CalendarProviders::TransientError.new(code: "provider_unavailable"))
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)

    get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }

    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      last_error_code: "revocation_failed"
    )
    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
    expect(response).to redirect_to(calendar_connection_path)
  end

  it "cleans up replacement credentials even when prior-revocation compensation fails" do
    connection = create(:calendar_connection, sync_status: "action_required", last_error_code: "authorization_required")
    user = connection.user
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "replacement-access",
      refresh_token: "replacement-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    provider = instance_double(CalendarProviders::Google, revoke: true)
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)
    allow(AuditEvent).to receive(:record!).and_wrap_original do |original, **attributes|
      if attributes[:action] == "calendar.connection.created"
        raise ActiveRecord::ConnectionNotEstablished, "replacement persistence failed"
      elsif attributes[:action] == "calendar.connection.revoked"
        raise ActiveRecord::ConnectionNotEstablished, "compensation failed"
      end

      original.call(**attributes)
    end

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.to raise_error(ActiveRecord::ConnectionNotEstablished, "compensation failed")

    expect(provider).to have_received(:revoke)
    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
  end

  it "revokes exchanged credentials when persistence fails unexpectedly" do
    user = create(:user)
    sign_in user
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "uncommitted-access",
      refresh_token: "uncommitted-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(user.calendar_connection_generation)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow(CalendarConnections::SaveCredentials).to receive(:call).and_raise(ActiveRecord::ConnectionNotEstablished)
    allow(CalendarConnections::GoogleOauth).to receive(:revoke).with(credentials:).and_return(true)

    expect do
      get callback_calendar_connection_path, params: { code: "oauth-code", state: "signed-state" }
    end.to raise_error(ActiveRecord::ConnectionNotEstablished)

    expect(CalendarConnections::GoogleOauth).to have_received(:revoke).with(credentials:)
  end

  it "rejects a callback with invalid state before exchanging the code" do
    user = create(:user)
    sign_in user
    allow(CalendarConnections::OauthState).to receive(:verify).and_return(false)
    allow(CalendarConnections::GoogleOauth).to receive(:exchange)

    get callback_calendar_connection_path, params: { code: "oauth-code", state: "bad" }

    expect(response).to redirect_to(calendar_connection_path)
    expect(user.reload.calendar_connection).to be_nil
    expect(CalendarConnections::GoogleOauth).not_to have_received(:exchange)
  end

  it "updates only supported selections and queues reconciliation" do
    connection = create(:calendar_connection, sync_types: [])
    sign_in connection.user

    expect do
      patch calendar_connection_path, params: { calendar_connection: { sync_types: %w[reminders commitments unknown] } }
    end.to have_enqueued_job(CalendarSyncJob).with(connection, owner_requested: true)

    expect(connection.reload.sync_types).to contain_exactly("reminders", "commitments")
    expect(response).to redirect_to(calendar_connection_path)
  end

  it "queues a recoverable manual sync" do
    connection = create(:calendar_connection, sync_status: "failed", last_error_code: "provider_unavailable")
    sign_in connection.user

    expect { post sync_calendar_connection_path }
      .to have_enqueued_job(CalendarSyncJob).with(connection, owner_requested: true)

    expect(response).to redirect_to(calendar_connection_path)
  end

  it "queues an owner-requested recovery after a permanent sync failure" do
    connection = create(:calendar_connection, sync_status: "failed", last_error_code: "provider_rejected")
    sign_in connection.user

    expect { post sync_calendar_connection_path }
      .to have_enqueued_job(CalendarSyncJob).with(connection, owner_requested: true)

    expect(response).to redirect_to(calendar_connection_path)
  end

  it "disconnects only after provider revocation succeeds" do
    connection = create(:calendar_connection)
    sign_in connection.user
    allow(CalendarConnections::Disconnect).to receive(:call).with(connection:, actor: connection.user).and_return(true)

    delete calendar_connection_path

    expect(response).to redirect_to(calendar_connection_path)
    expect(flash[:notice]).to be_present
  end
end
