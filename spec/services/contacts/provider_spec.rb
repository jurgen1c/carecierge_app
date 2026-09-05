require 'rails_helper'

RSpec.describe 'Contacts provider lifecycle' do
  let(:user) { create(:user) }
  let(:credentials) { Contacts::GoogleOauth::Credentials.new(access_token: 'access', refresh_token: 'refresh', expires_at: 1.hour.from_now, scopes: [ ContactsConnection::GOOGLE_SCOPE ]) }
  let(:connection) { ContactsConnection.create!(user:, access_token: 'access', refresh_token: 'refresh', token_expires_at: 1.hour.from_now) }
  before { allow(Contacts::Permission).to receive(:check!) }

  it 'binds expiring single-use state to the owner and generation' do
    session = {}
    state = Contacts::OauthState.issue(user:, session:)
    expect(Contacts::OauthState.verify(state:, user: create(:user), session: session.dup)).to be(false)
    expect(Contacts::OauthState.verify(state:, user:, session:)).to eq(0)
    expect(Contacts::OauthState.verify(state:, user:, session:)).to be(false)
    Timecop.freeze(Time.current) do
      state = Contacts::OauthState.issue(user:, session:)
      Timecop.travel(11.minutes.from_now) { expect(Contacts::OauthState.verify(state:, user:, session:)).to be(false) }
    end
  end

  it 'connects without importing and rejects a callback invalidated by disconnect' do
    allow(Contacts::GoogleOauth).to receive(:exchange).and_return(credentials)
    expect { Contacts::Connect.call(user:, code: 'code', redirect_uri: 'https://example.com/callback', generation: 0) }.to change(ContactsConnection, :count).by(1)
    expect(ImportedContact.count).to eq(0)
    user.reload.increment!(:contacts_connection_generation)
    expect { Contacts::Connect.call(user:, code: 'code', redirect_uri: 'https://example.com/callback', generation: 0) }.to raise_error(Contacts::Error)
    expect(Contacts::GoogleOauth).to have_received(:exchange).once
  end

  it 'retains unusable callback credentials for explicit cleanup if revocation fails' do
    allow(Contacts::GoogleOauth).to receive(:exchange).and_raise(Contacts::Error.new(code: 'invalid_provider_response', credentials:))
    allow(Contacts::GoogleOauth).to receive(:revoke).and_raise(Contacts::Error)
    expect { Contacts::Connect.call(user:, code: 'code', redirect_uri: 'https://example.com/callback', generation: 0) }.to raise_error(Contacts::Error)
    expect(user.reload.contacts_connection.status).to eq('cleanup_required')
    expect(user.contacts_connection.refresh_token).to eq('refresh')
  end

  it 'keeps failed revocation credentials and deletes only provider data after successful retry' do
    contact = connection.imported_contacts.create!(provider_key: 'key', external_id: 'people/1', data: { 'first_name' => 'Elena' })
    profile = create(:relationship_profile, user:)
    contact.update!(relationship_profile: profile)
    allow(Contacts::GoogleOauth).to receive(:revoke).and_raise(Contacts::Error)
    expect(Contacts::Disconnect.call(user:)).to be(false)
    expect(connection.reload.status).to eq('cleanup_required')
    allow(Contacts::GoogleOauth).to receive(:revoke).and_return(true)
    expect(Contacts::Disconnect.call(user:)).to be(true)
    expect(ContactsConnection.exists?(connection.id)).to be(false)
    expect(profile.reload).to be_persisted
  end

  it 'stages a bounded provider page, preserving decisions and avoiding automatic profile updates' do
    provider = instance_double(Contacts::Google, page: { contacts: [ { 'external_id' => 'people/1', 'first_name' => 'Elena', 'email' => 'elena@example.com' } ], next_page_token: 'next' })
    allow(Contacts::Google).to receive(:new).and_return(provider)
    expect { Contacts::Refresh.call(user:, more: false) }.to raise_error(ActiveRecord::RecordNotFound)
    connection
    expect { Contacts::Refresh.call(user:, more: false) }.to change(ImportedContact, :count).by(1)
    expect(RelationshipProfile.count).to eq(0)
    imported = connection.imported_contacts.first
    imported.update!(decision: 'skip')
    Contacts::Refresh.call(user:, more: false)
    expect(imported.reload.decision).to eq('skip')
    expect(connection.reload.next_page_token).to eq('next')
    expect(user.audit_events.last.metadata['count']).to eq(1)
  end
end

RSpec.describe 'Contacts rollback cleanup' do
  let(:user) { create(:user) }
  let(:credentials) { Contacts::GoogleOauth::Credentials.new(access_token: 'access', refresh_token: 'refresh', expires_at: 1.hour.from_now, scopes: [ ContactsConnection::GOOGLE_SCOPE ]) }
  before { allow(Contacts::Permission).to receive(:check!) }

  it 'revokes a callback token if local audit persistence fails' do
    allow(Contacts::GoogleOauth).to receive(:exchange).and_return(credentials)
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)
    expect(Contacts::GoogleOauth).to receive(:revoke).with(credentials:)
    expect { Contacts::Connect.call(user:, code: 'code', redirect_uri: 'https://example.com', generation: 0) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(user.reload.contacts_connection).to be_nil
  end

  it 'fences a restored connection when local disconnect rolls back after revocation' do
    connection = ContactsConnection.create!(user:, access_token: 'access', refresh_token: 'refresh')
    allow(Contacts::GoogleOauth).to receive(:revoke).and_return(true)
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid)
    expect { Contacts::Disconnect.call(user:) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(connection.reload.status).to eq('authorization_required')
  end
end
