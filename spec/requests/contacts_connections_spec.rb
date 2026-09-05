require 'rails_helper'

RSpec.describe 'Contacts connections', type: :request do
  let(:user) { create(:user) }
  let(:connection) { ContactsConnection.create!(user:, access_token: 'access', refresh_token: 'refresh') }
  before { sign_in user }

  it 'shows setup availability and Spanish parity without exposing credentials' do
    allow(Contacts::GoogleOauth).to receive(:available?).and_return(false)
    get contacts_connection_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Contacts', 'not available')
    I18n.with_locale(:es) { get contacts_connection_path }
    expect(response.body).to include('Contactos', 'no está disponible')
  end

  it 'shows a labeled manual review form and imports only the chosen contact' do
    allow(Contacts::Permission).to receive(:check!)
    contact = connection.imported_contacts.create!(provider_key: 'one', external_id: 'people/1', data: { 'first_name' => 'Elena' })
    get contacts_connection_path
    expect(response.body).to include('Elena', 'Create profile', 'Skip for now')
    expect(response.headers['Cache-Control']).to include('no-store')
    expect { post decide_contacts_connection_path(contact_id: contact.id), params: { choice: 'create', lock_version: contact.lock_version } }.to change(RelationshipProfile, :count).by(1)
    expect(response).to redirect_to(contacts_connection_path)
  end

  it 'does not query duplicate candidates for an already linked contact' do
    allow(Contacts::Permission).to receive(:check!)
    contact = connection.imported_contacts.create!(provider_key: 'one', external_id: 'people/1', data: { 'first_name' => 'Elena' })
    Contacts::Decide.call(contact:, actor: user, choice: 'create', expected_version: contact.lock_version)
    expect(Contacts::Matches).not_to receive(:call)

    get contacts_connection_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Elena')
  end

  it 'rejects cross-owner contact ids and stale versions' do
    foreign = ContactsConnection.create!(user: create(:user))
    contact = foreign.imported_contacts.create!(provider_key: 'one', external_id: 'people/1', data: { 'first_name' => 'Private' })
    connection
    post decide_contacts_connection_path(contact_id: contact.id), params: { choice: 'create', lock_version: 0 }
    expect(response).to have_http_status(:not_found)
  end

  it 'never exchanges a code with invalid state' do
    expect(Contacts::GoogleOauth).not_to receive(:exchange)
    get callback_contacts_connection_path, params: { state: 'bad', code: 'secret' }
    expect(response).to redirect_to(contacts_connection_path)
  end

  it 'exports safe source data but never provider credentials or paging tokens' do
    connection.update!(next_page_token: 'paging-secret')
    connection.imported_contacts.create!(provider_key: 'one', external_id: 'people/private-id', data: { 'first_name' => 'Elena' })
    export = DataExports::Snapshot.new(user:).to_h.fetch('contacts_connection')
    expect(export.to_s).to include('Elena', 'google_contacts')
    expect(export.to_s).not_to include('paging-secret', 'people/private-id', 'refresh_token', 'access_token')
  end

  it 'retains the account when contacts revocation fails' do
    connection
    allow(Contacts::GoogleOauth).to receive(:revoke).and_raise(Contacts::Error)
    expect { DataDeletions::DeleteAccount.call(user:) }.to raise_error(DataDeletions::DeleteAccount::CalendarRevocationError)
    expect(User.exists?(user.id)).to be(true)
    expect(connection.reload.status).to eq('cleanup_required')
  end
  it 'returns actionable feedback without changing a profile when Google removes its name' do
    allow(Contacts::Permission).to receive(:check!)
    contact = connection.imported_contacts.create!(provider_key: 'one', external_id: 'people/1', data: { 'first_name' => 'Elena' })
    Contacts::Decide.call(contact:, actor: user, choice: 'create', expected_version: contact.lock_version)
    profile = contact.reload.relationship_profile
    contact.update!(data: { 'first_name' => '' })
    post decide_contacts_connection_path(contact_id: contact.id), params: { choice: 'update', lock_version: contact.lock_version }
    expect(response).to redirect_to(contacts_connection_path)
    follow_redirect!
    expect(response.body).to include('This contact needs a name')
    expect(profile.reload.first_name).to eq('Elena')
  end

  it 'handles incomplete OAuth callbacks without an unhandled parameter error' do
    allow(Contacts::OauthState).to receive(:verify).and_return(0)
    get callback_contacts_connection_path, params: { state: 'valid-state' }
    expect(response).to redirect_to(contacts_connection_path)
  end
  %w[authorization_required cleanup_required].each do |status|
    it "keeps local reversal available when the provider is #{status}" do
      allow(Contacts::Permission).to receive(:check!)
      contact = connection.imported_contacts.create!(provider_key: 'one', external_id: 'people/1', data: { 'first_name' => 'Elena' })
      Contacts::Decide.call(contact:, actor: user, choice: 'create', expected_version: contact.lock_version)
      profile = contact.reload.relationship_profile
      connection.update!(status:)
      get contacts_connection_path
      document = Nokogiri::HTML(response.body)
      expect(document.css('select[name="choice"] option').map { |option| option['value'] }).to eq([ 'undo' ])
      expect(response.body).not_to include('name="profile_id"')
      post decide_contacts_connection_path(contact_id: contact.id), params: { choice: 'update', lock_version: contact.lock_version }
      expect(profile.reload.first_name).to eq('Elena')
      expect(flash[:alert]).to be_present
      expect(Contacts::Google).not_to receive(:new)
      post decide_contacts_connection_path(contact_id: contact.id), params: { choice: 'undo', lock_version: contact.lock_version }
      expect(profile.reload).to be_discarded
      expect(contact.reload.relationship_profile_id).to be_nil
    end
  end
end
