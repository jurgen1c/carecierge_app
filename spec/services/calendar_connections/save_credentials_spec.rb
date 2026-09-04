require "rails_helper"

RSpec.describe CalendarConnections::SaveCredentials do
  it "consumes the generation when credentials are accepted" do
    user = create(:user)
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "access", refresh_token: "refresh", expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )

    described_class.call(user:, credentials:, actor: user, expected_generation: 0)

    expect(user.reload.calendar_connection_generation).to eq(1)
    expect do
      described_class.call(user:, credentials:, actor: user, expected_generation: 0)
    end.to raise_error(CalendarConnections::ConnectionError) { |error| expect(error.code).to eq("stale_authorization") }
  end

  it "creates an encrypted owner connection and audits the consent boundary" do
    user = create(:user)
    credentials = oauth_credentials
    expect(user).to receive(:with_lock).with("FOR NO KEY UPDATE").and_call_original

    expect { described_class.call(user:, credentials:, actor: user, expected_generation: 0, locale: :es) }
      .to change(CalendarConnection, :count).by(1)
      .and change { AuditEvent.where(action: "calendar.connection.created").count }.by(1)

    expect(user.reload.calendar_connection).to have_attributes(
      access_token: "fresh-access",
      refresh_token: "fresh-refresh",
      granted_scopes: [ CalendarConnection::GOOGLE_SCOPE ],
      sync_types: [],
      locale: "es"
    )
  end

  it "reconnects in place while preserving the owner's sync choices" do
    connection = create(:calendar_connection, sync_types: [ "reminders" ], sync_status: "action_required", last_error_code: "invalid_grant")
    mapping = create(:calendar_event_sync, calendar_connection: connection)
    provider = instance_double(CalendarProviders::Google, revoke: true)
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)

    expect do
      described_class.call(
        user: connection.user,
        credentials: oauth_credentials,
        actor: connection.user,
        expected_generation: connection.user.calendar_connection_generation
      )
    end.not_to change(CalendarConnection, :count)

    expect(connection.reload).to have_attributes(
      access_token: "fresh-access",
      refresh_token: "fresh-refresh",
      sync_types: [ "reminders" ],
      sync_status: "connected",
      last_error_code: nil
    )
    expect(mapping.reload.synced_at).to be_nil
    expect(provider).to have_received(:revoke)
  end

  it "refuses to replace credentials while provider revocation is unresolved" do
    connection = create(:calendar_connection, sync_status: "failed", last_error_code: "revocation_failed")
    original_refresh_token = connection.refresh_token

    expect do
      described_class.call(
        user: connection.user,
        credentials: oauth_credentials,
        actor: connection.user,
        expected_generation: connection.user.calendar_connection_generation
      )
    end.to raise_error(CalendarConnections::ConnectionError) { |error| expect(error.code).to eq("revocation_failed") }

    expect(connection.reload.refresh_token).to eq(original_refresh_token)
  end

  it "preserves existing credentials when their revocation cannot be confirmed" do
    connection = create(:calendar_connection, sync_status: "action_required", last_error_code: "authorization_required")
    provider = instance_double(CalendarProviders::Google)
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
    allow(provider).to receive(:revoke)
      .and_raise(CalendarProviders::TransientError.new(code: "provider_unavailable"))

    expect do
      described_class.call(
        user: connection.user,
        credentials: oauth_credentials,
        actor: connection.user,
        expected_generation: connection.user.calendar_connection_generation
      )
    end.to raise_error(CalendarConnections::ConnectionError) { |error| expect(error.code).to eq("revocation_failed") }

    expect(connection.reload).to have_attributes(
      access_token: "access-token",
      refresh_token: "refresh-token",
      sync_status: "action_required"
    )
  end

  it "rejects credentials from an authorization superseded by disconnect" do
    user = create(:user, calendar_connection_generation: 2)

    expect do
      described_class.call(user:, credentials: oauth_credentials, actor: user, expected_generation: 1)
    end.to raise_error(CalendarConnections::ConnectionError) { |error| expect(error.code).to eq("stale_authorization") }

    expect(user.reload.calendar_connection).to be_nil
  end


  it "refuses credentials while callback cleanup is pending" do
    pending = create(:calendar_credential_revocation)

    expect do
      described_class.call(
        user: pending.user, credentials: oauth_credentials, actor: pending.user,
        expected_generation: pending.user.calendar_connection_generation
      )
    end.to raise_error(CalendarConnections::ConnectionError) { |error| expect(error.code).to eq("revocation_failed") }
  end

  def oauth_credentials
    CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "fresh-access",
      refresh_token: "fresh-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
  end
end
