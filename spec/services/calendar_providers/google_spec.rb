require "rails_helper"

RSpec.describe CalendarProviders::Google do
  let(:connection) { create(:calendar_connection, access_token: "private-access") }
  let(:http) { instance_double(Net::HTTP) }
  let(:client) { described_class.new(connection:) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  it "creates a private event with a bearer token and returns the provider id" do
    request = nil
    allow(http).to receive(:request) do |outbound|
      request = outbound
      response(Net::HTTPOK, body: { id: "provider-event" }.to_json)
    end

    id = client.create_event(
      { summary: "Private title", start: { date_time: "2026-09-03T12:00:00Z" }, visibility: "private" },
      event_id: "carecierge-event"
    )

    expect(id).to eq("provider-event")
    expect(request["Authorization"]).to eq("Bearer private-access")
    expect(JSON.parse(request.body)).to include(
      "summary" => "Private title",
      "id" => "carecierge-event",
      "start" => { "dateTime" => "2026-09-03T12:00:00Z" },
      "visibility" => "private"
    )
  end

  it "refreshes an expired token and persists only normalized credentials" do
    connection.update!(token_expires_at: 1.minute.ago)
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "fresh-access",
      refresh_token: "fresh-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::GoogleOauth).to receive(:refresh).and_return(credentials)
    allow(http).to receive(:request).and_return(response(Net::HTTPOK, body: { id: "provider-event" }.to_json))

    client.create_event({ summary: "Title" }, event_id: "carecierge-event")

    expect(CalendarConnections::GoogleOauth).to have_received(:refresh).with(refresh_token: "refresh-token")
    expect(connection.reload).to have_attributes(access_token: "fresh-access", refresh_token: "fresh-refresh")
  end

  it "keeps refresh network failures retryable" do
    connection.update!(token_expires_at: 1.minute.ago)
    allow(CalendarConnections::GoogleOauth).to receive(:refresh).and_raise(
      CalendarConnections::ConnectionError.new(code: "provider_unavailable")
    )

    expect { client.create_event({ summary: "Title" }, event_id: "carecierge-event") }
      .to raise_error(CalendarProviders::TransientError) { |error| expect(error.code).to eq("provider_unavailable") }
  end

  it "keeps token endpoint throttling retryable" do
    connection.update!(token_expires_at: 1.minute.ago)
    allow(CalendarConnections::GoogleOauth).to receive(:refresh).and_raise(
      CalendarConnections::ConnectionError.new(code: "rate_limited")
    )

    expect { client.create_event({ summary: "Title" }, event_id: "carecierge-event") }
      .to raise_error(CalendarProviders::TransientError) { |error| expect(error.code).to eq("rate_limited") }
  end

  it "classifies authorization, throttling, and validation responses without retaining provider bodies" do
    cases = [
      [ Net::HTTPUnauthorized, CalendarProviders::AuthorizationError, "authorization_required" ],
      [ Net::HTTPTooManyRequests, CalendarProviders::TransientError, "rate_limited" ],
      [ Net::HTTPBadRequest, CalendarProviders::PermanentError, "provider_rejected" ],
      [ Net::HTTPNotFound, CalendarProviders::NotFoundError, "provider_event_missing" ],
      [ Net::HTTPGone, CalendarProviders::NotFoundError, "provider_event_missing" ]
    ]

    cases.each do |response_class, error_class, code|
      allow(http).to receive(:request).and_return(response(response_class, body: "private provider body"))

      expect { client.create_event({ summary: "Title" }, event_id: "carecierge-event") }
        .to raise_error(error_class) { |error| expect(error.code).to eq(code) }
    end
  end

  it "reconciles a retained event after a deterministic id conflict" do
    requests = []
    allow(http).to receive(:request) do |request|
      requests << request
      requests.one? ? response(Net::HTTPConflict) : response(Net::HTTPOK, body: { id: "carecierge-event" }.to_json)
    end

    expect(client.create_event({ summary: "Title" }, event_id: "carecierge-event")).to eq("carecierge-event")
    expect(requests.map(&:method)).to eq(%w[POST PUT])
    expect(JSON.parse(requests.last.body)).to include("summary" => "Title")
  end

  it "keeps quota-related forbidden responses retryable" do
    body = { error: { errors: [ { reason: "userRateLimitExceeded" } ] } }.to_json
    allow(http).to receive(:request).and_return(response(Net::HTTPForbidden, body:))

    expect { client.create_event({ summary: "Title" }, event_id: "carecierge-event") }
      .to raise_error(CalendarProviders::TransientError) { |error| expect(error.code).to eq("rate_limited") }
  end

  it "classifies DNS failures as transient without exposing their details" do
    allow(Net::HTTP).to receive(:start).and_raise(SocketError, "private host detail")

    expect { client.create_event({ summary: "Title" }, event_id: "carecierge-event") }
      .to raise_error(CalendarProviders::TransientError) { |error| expect(error.code).to eq("provider_unavailable") }
  end

  it "treats an already invalid token as successfully revoked" do
    request = nil
    allow(http).to receive(:request) do |outbound|
      request = outbound
      response(Net::HTTPBadRequest)
    end

    expect(client.revoke).to be(true)
    expect(request.body).to eq("token=refresh-token")
    expect(request["Authorization"]).to be_nil
  end

  def response(response_class, body: "")
    status = {
      Net::HTTPOK => [ "200", "OK" ],
      Net::HTTPBadRequest => [ "400", "Bad Request" ],
      Net::HTTPUnauthorized => [ "401", "Unauthorized" ],
      Net::HTTPForbidden => [ "403", "Forbidden" ],
      Net::HTTPConflict => [ "409", "Conflict" ],
      Net::HTTPTooManyRequests => [ "429", "Too Many Requests" ],
      Net::HTTPNotFound => [ "404", "Not Found" ],
      Net::HTTPGone => [ "410", "Gone" ]
    }.fetch(response_class)
    response = response_class.new("1.1", *status)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end
end
