require 'rails_helper'

RSpec.describe Messaging::Google do
  let(:connection) { MessagingConnection.create!(user: create(:user), access_token: 'private-token', refresh_token: 'refresh', token_expires_at: 1.hour.from_now) }
  let(:http) { instance_double(Net::HTTP) }
  before { allow(Net::HTTP).to receive(:start).and_yield(http) }

  it 'uses only fixed-host GET reads and stores no search results' do
    requests = []
    allow(http).to receive(:request) do |request|
      requests << request
      data = request.path.include?('/abc123') ? { id: 'abc123', threadId: 'def456', snippet: 'Lunch &amp; plans', payload: { headers: [ { name: 'Subject', value: 'Catch up' } ] } } : { messages: [ { id: 'abc123' } ] }
      response(data)
    end
    results = described_class.new(connection:).search(query: 'from:friend@example.com')
    expect(results.first).to include(subject: 'Catch up', snippet: 'Lunch & plans')
    expect(ImportedMessageContext.count).to eq(0)
    expect(requests).to all(be_a(Net::HTTP::Get))
    expect(requests.first['Authorization']).to eq('Bearer private-token')
    expect(requests.last.path).to include('fields=id%2CthreadId%2Csnippet%2Cpayload%28headers%29')
  end

  it 'rejects URL injection, unbounded queries and malformed provider data' do
    expect(http).not_to receive(:request)
    provider = described_class.new(connection:)
    [ '../send', 'https://evil.test', {}, nil ].each do |id|
      expect { provider.message(external_id: id) }.to raise_error(Messaging::Error)
    end
    [ '', 'a' * 301, [] ].each do |query|
      expect { provider.search(query:) }.to raise_error(Messaging::Error)
    end
  end

  it 'rejects mismatched identities and bounds result counts' do
    allow(http).to receive(:request).and_return(response(id: 'beef', threadId: 'def456', snippet: 'secret'))
    expect { described_class.new(connection:).message(external_id: 'abc123') }.to raise_error(Messaging::Error)
    allow(http).to receive(:request).and_return(response(messages: Array.new(11) { { id: 'abc123' } }))
    expect { described_class.new(connection:).search(query: 'subject:test') }.to raise_error(Messaging::Error)
  end

  it 'refreshes expired credentials before reading and preserves rotated credentials encrypted' do
    connection.update!(token_expires_at: 1.minute.ago)
    credentials = Messaging::GoogleOauth::Credentials.new(access_token: 'fresh', refresh_token: 'rotated', expires_at: 1.hour.from_now, scopes: [ MessagingConnection::GOOGLE_SCOPE ])
    expect(Messaging::GoogleOauth).to receive(:refresh).with(refresh_token: 'refresh').and_return(credentials)
    allow(http).to receive(:request).and_return(response(id: 'abc123', threadId: 'def456', snippet: 'excerpt'))
    described_class.new(connection:).message(external_id: 'abc123')
    expect(connection.reload.refresh_token).to eq('rotated')
    expect(connection.read_attribute_before_type_cast(:refresh_token)).not_to include('rotated')
  end

  def response(data)
    result = Net::HTTPOK.new('1.1', '200', 'OK')
    result.instance_variable_set(:@body, data.to_json)
    result.instance_variable_set(:@read, true)
    result
  end
end
