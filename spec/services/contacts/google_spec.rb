require 'rails_helper'

RSpec.describe Contacts::Google do
  let(:connection) { ContactsConnection.create!(user: create(:user), access_token: 'private', refresh_token: 'refresh', token_expires_at: 1.hour.from_now) }
  let(:http) { instance_double(Net::HTTP) }
  before { allow(Net::HTTP).to receive(:start).and_yield(http) }
  def response(klass, payload)
    result = klass.new('1.1', { Net::HTTPOK => '200', Net::HTTPUnauthorized => '401', Net::HTTPForbidden => '403', Net::HTTPServiceUnavailable => '503', Net::HTTPTooManyRequests => '429', Net::HTTPInternalServerError => '500' }.fetch(klass), 'response')
    allow(result).to receive(:body).and_return(payload.to_json)
    result
  end

  it 'requests a narrow read-only page and normalizes only reviewed fields' do
    allow(http).to receive(:request) do |request|
      expect(request['Authorization']).to eq('Bearer private')
      query = Rack::Utils.parse_query(URI(request.path).query)
      expect(query).to include('personFields' => 'names,emailAddresses,phoneNumbers,birthdays', 'pageSize' => '100', 'pageToken' => 'next')
      response(Net::HTTPOK, { 'connections' => [ { 'resourceName' => 'people/1', 'names' => [ { 'givenName' => 'Elena', 'familyName' => 'Ruiz' } ], 'birthdays' => [ { 'date' => { 'year' => 1990, 'month' => 5, 'day' => 4 } } ], 'biographies' => [ { 'value' => 'private' } ] } ] })
    end
    page = described_class.new(connection:).page(page_token: 'next')
    expect(page[:contacts].first).to include('birthday' => '1990-05-04', 'first_name' => 'Elena')
    expect(page.to_s).not_to include('biographies', 'private')
  end

  it 'refreshes expired tokens and surfaces revoked authorization' do
    connection.update!(token_expires_at: 1.minute.ago)
    credentials = Contacts::GoogleOauth::Credentials.new(access_token: 'new', refresh_token: 'refresh', expires_at: 1.hour.from_now, scopes: [ ContactsConnection::GOOGLE_SCOPE ])
    expect(Contacts::GoogleOauth).to receive(:refresh).and_return(credentials)
    allow(http).to receive(:request).and_return(response(Net::HTTPUnauthorized, {}))
    expect { described_class.new(connection:).page }.to raise_error(Contacts::Error, /Contacts/)
    expect(connection.reload.access_token).to eq('new')
  end

  it 'rejects oversized pages and provider outages' do
    allow(http).to receive(:request).and_return(response(Net::HTTPOK, { 'connections' => Array.new(101) { {} } }))
    expect { described_class.new(connection:).page }.to raise_error(Contacts::Error)
    allow(http).to receive(:request).and_return(response(Net::HTTPServiceUnavailable, {}))
    expect { described_class.new(connection:).page }.to raise_error(Contacts::Error)
  end
  it 'uses the complete display-name fallback without duplicating the surname' do
    allow(http).to receive(:request).and_return(response(Net::HTTPOK, { 'connections' => [
      { 'resourceName' => 'people/1', 'names' => [ { 'displayName' => 'Ruiz', 'familyName' => 'Ruiz' } ] }
    ] }))
    contact = described_class.new(connection:).page[:contacts].first
    expect(contact.values_at('first_name', 'last_name')).to eq([ 'Ruiz', nil ])
  end
  it 'keeps quota and service-disabled 403 failures recoverable without discarding review data' do
    %w[rateLimitExceeded SERVICE_DISABLED].each do |reason|
      allow(http).to receive(:request).and_return(response(Net::HTTPForbidden, { 'error' => { 'errors' => [ { 'reason' => reason } ] } }))
      expect { described_class.new(connection:).page }.to raise_error(Contacts::Error) { |error| expect(error.code).to eq('provider_unavailable') }
    end
  end

  it 'requires new authorization for explicit insufficient-scope provider errors' do
    allow(http).to receive(:request).and_return(response(Net::HTTPForbidden, { 'error' => { 'details' => [ { 'reason' => 'ACCESS_TOKEN_SCOPE_INSUFFICIENT' } ] } }))
    expect { described_class.new(connection:).page }.to raise_error(Contacts::Error) { |error| expect(error.code).to eq('authorization_required') }
  end
  it 'preserves the staged connection through quota, server and nonauthorization forbidden failures' do
    allow(Contacts::Permission).to receive(:check!)
    [ Net::HTTPTooManyRequests, Net::HTTPInternalServerError, Net::HTTPServiceUnavailable, Net::HTTPForbidden ].each do |klass|
      allow(http).to receive(:request).and_return(response(klass, {}))
      expect { Contacts::Refresh.call(user: connection.user) }.to raise_error(Contacts::Error)
      expect(connection.reload.status).to eq('connected')
    end
    allow(http).to receive(:request).and_return(response(Net::HTTPUnauthorized, {}))
    expect { Contacts::Refresh.call(user: connection.user) }.to raise_error(Contacts::Error)
    expect(connection.reload.status).to eq('authorization_required')
  end
end
