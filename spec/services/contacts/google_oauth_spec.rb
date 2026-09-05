require "rails_helper"

RSpec.describe Contacts::GoogleOauth do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_CONTACTS_ISOLATED_PROJECT").and_return("true")
    allow(ENV).to receive(:[]).with("GOOGLE_CONTACTS_CLIENT_ID").and_return("contacts-client")
    allow(ENV).to receive(:[]).with("GOOGLE_CONTACTS_CLIENT_SECRET").and_return("contacts-secret")
  end

  it "builds an offline authorization URL with the read-only contacts scope" do
    uri = URI.parse(described_class.authorization_url(state: "signed-state", redirect_uri: "https://example.test/callback"))
    query = Rack::Utils.parse_query(uri.query)

    expect(uri.host).to eq("accounts.google.com")
    expect(query).to include(
      "client_id" => "contacts-client",
      "redirect_uri" => "https://example.test/callback",
      "scope" => ContactsConnection::GOOGLE_SCOPE,
      "access_type" => "offline",
      "include_granted_scopes" => "false",
      "prompt" => "consent",
      "state" => "signed-state"
    )
  end

  it "is unavailable without dedicated contacts credentials" do
    allow(ENV).to receive(:[]).with("GOOGLE_CONTACTS_CLIENT_ID").and_return(nil)
    allow(ENV).to receive(:[]).with("GOOGLE_CONTACTS_CLIENT_SECRET").and_return(nil)

    expect(described_class).not_to be_available
  end

  it "exchanges a code for normalized credentials without exposing client secrets" do
    request = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |outbound|
      request = outbound
      response(
        Net::HTTPOK,
        body: {
          access_token: "private-access",
          refresh_token: "private-refresh",
          expires_in: 1800,
          scope: ContactsConnection::GOOGLE_SCOPE
        }.to_json
      )
    end

    credentials = described_class.exchange(code: "oauth-code", redirect_uri: "https://example.test/callback")

    expect(credentials).to have_attributes(
      access_token: "private-access",
      refresh_token: "private-refresh",
      scopes: [ ContactsConnection::GOOGLE_SCOPE ]
    )
    expect(Rack::Utils.parse_query(request.body)).to include(
      "code" => "oauth-code",
      "client_id" => "contacts-client",
      "client_secret" => "contacts-secret",
      "grant_type" => "authorization_code"
    )
    expect(request["Authorization"]).to be_nil
  end

  it "retains the existing refresh token when Google rotates only the access token" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(
      response(Net::HTTPOK, body: { access_token: "fresh-access", expires_in: 3600 }.to_json)
    )

    credentials = described_class.refresh(refresh_token: "existing-refresh")

    expect(credentials.refresh_token).to eq("existing-refresh")
    expect(credentials.scopes).to eq([ ContactsConnection::GOOGLE_SCOPE ])
  end

  it "preserves live tokens from an incomplete exchange for revocation" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(
      response(Net::HTTPOK, body: { access_token: "orphan-access", expires_in: 3600, scope: "profile" }.to_json)
    )

    expect { described_class.exchange(code: "oauth-code", redirect_uri: "https://example.test/callback") }
      .to raise_error(Contacts::Error) { |error|
        expect(error.code).to eq("authorization_required")
        expect(error.credentials).to have_attributes(access_token: "orphan-access", refresh_token: nil)
      }
  end

  it "revokes newly exchanged credentials without persisting or exposing them" do
    request = nil
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |outbound|
      request = outbound
      response(Net::HTTPOK)
    end
    credentials = Contacts::GoogleOauth::Credentials.new(
      access_token: "private-access",
      refresh_token: "private-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ ContactsConnection::GOOGLE_SCOPE ]
    )

    expect(described_class.revoke(credentials:)).to be(true)

    expect(Rack::Utils.parse_query(request.body)).to eq("token" => "private-refresh")
    expect(request["Authorization"]).to be_nil
  end

  it "normalizes malformed and provider error responses into safe codes" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response(Net::HTTPBadRequest, body: { error: "invalid_grant" }.to_json))

    expect { described_class.refresh(refresh_token: "existing-refresh") }
      .to raise_error(Contacts::Error) { |error| expect(error.code).to eq("invalid_grant") }

    allow(http).to receive(:request).and_return(response(Net::HTTPOK, body: "not-json"))
    expect { described_class.refresh(refresh_token: "existing-refresh") }
      .to raise_error(Contacts::Error) { |error| expect(error.code).to eq("invalid_provider_response") }
  end

  it "normalizes DNS failures into a recoverable safe code" do
    allow(Net::HTTP).to receive(:start).and_raise(SocketError, "private host detail")

    expect { described_class.refresh(refresh_token: "existing-refresh") }
      .to raise_error(Contacts::Error) { |error| expect(error.code).to eq("provider_unavailable") }
  end

  it "normalizes token endpoint throttling and outages into retryable safe codes" do
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(
      response(Net::HTTPTooManyRequests, body: ""),
      response(Net::HTTPServiceUnavailable, body: "<html>unavailable</html>")
    )

    expect { described_class.refresh(refresh_token: "existing-refresh") }
      .to raise_error(Contacts::Error) { |error| expect(error.code).to eq("rate_limited") }
    expect { described_class.refresh(refresh_token: "existing-refresh") }
      .to raise_error(Contacts::Error) { |error| expect(error.code).to eq("provider_unavailable") }
  end

  def response(response_class, body: "")
    status = {
      Net::HTTPOK => [ "200", "OK" ],
      Net::HTTPBadRequest => [ "400", "Bad Request" ],
      Net::HTTPTooManyRequests => [ "429", "Too Many Requests" ],
      Net::HTTPServiceUnavailable => [ "503", "Service Unavailable" ]
    }.fetch(response_class)
    response = response_class.new("1.1", *status)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end
end
