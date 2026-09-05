require 'rails_helper'

RSpec.describe Messaging::Connect do
  let(:user) { create(:user) }
  let(:credentials) { Messaging::GoogleOauth::Credentials.new(access_token: 'access', refresh_token: 'refresh', expires_at: 1.hour.from_now, scopes: [ MessagingConnection::GOOGLE_SCOPE ]) }
  before do
    create(:automation_permission, user:, capability: 'access_messages', mode: 'ask_every_time')
    allow_any_instance_of(Messaging::Google).to receive(:mailbox_email).and_return('secondary@example.com')
  end

  it 'connects once without importing and invalidates already issued OAuth attempts' do
    expect(Messaging::GoogleOauth).to receive(:exchange).once.and_return(credentials)
    connection = described_class.call(user:, code: 'code', redirect_uri: 'https://example.test/callback', generation: 0)
    expect(connection.imported_message_contexts).to be_empty
    expect(connection.mailbox_email).to eq('secondary@example.com')
    expect(connection.read_attribute_before_type_cast(:mailbox_email)).not_to include('secondary@example.com')
    expect(user.reload.messaging_connection_generation).to eq(1)
    expect { described_class.call(user:, code: 'other', redirect_uri: 'https://example.test/callback', generation: 0) }.to raise_error(Messaging::Error)
  end

  it 'revokes partial credentials from an invalid provider response' do
    allow(Messaging::GoogleOauth).to receive(:exchange).and_raise(Messaging::Error.new(credentials:))
    expect(Messaging::GoogleOauth).to receive(:revoke).with(credentials:)
    expect { described_class.call(user:, code: 'code', redirect_uri: 'https://example.test/callback', generation: 0) }.to raise_error(Messaging::Error)
    expect(MessagingConnection.exists?(user_id: user.id)).to be(false)
  end

  it 'retains unusable encrypted retry credentials when grant cleanup also fails' do
    allow(Messaging::GoogleOauth).to receive(:exchange).and_raise(Messaging::Error.new(credentials:))
    allow(Messaging::GoogleOauth).to receive(:revoke).and_raise(Messaging::Error)
    expect { described_class.call(user:, code: 'code', redirect_uri: 'https://example.test/callback', generation: 0) }.to raise_error(Messaging::Error)
    connection = MessagingConnection.find_by!(user:)
    expect(connection.status).to eq('cleanup_required')
    expect(connection.read_attribute_before_type_cast(:refresh_token)).not_to include('refresh')
    expect { Messaging::Access.call(user:) { } }.to raise_error(Messaging::Error)
  end

  it 'revokes exchanged credentials when mailbox identity cannot be verified' do
    allow(Messaging::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow_any_instance_of(Messaging::Google).to receive(:mailbox_email).and_raise(Messaging::Error)
    expect(Messaging::GoogleOauth).to receive(:revoke).with(credentials:)
    expect { described_class.call(user:, code: 'code', redirect_uri: 'https://example.test/callback', generation: 0) }.to raise_error(Messaging::Error)
    expect(MessagingConnection.exists?(user_id: user.id)).to be(false)
  end

  it 'prevents delayed callbacks from recreating a disconnected connection' do
    Messaging::Disconnect.call(user:)
    expect(Messaging::GoogleOauth).not_to receive(:exchange)
    expect { described_class.call(user:, code: 'code', redirect_uri: 'https://example.test/callback', generation: 0) }.to raise_error(Messaging::Error)
  end
end
