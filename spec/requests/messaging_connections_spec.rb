require 'rails_helper'

RSpec.describe 'Messaging connections', type: :request do
  let(:user) { create(:user) }
  let(:connection) { MessagingConnection.create!(user:, access_token: 'secret-access', refresh_token: 'secret-refresh') }
  let(:context) { connection.imported_message_contexts.create!(source_key: 'key', external_id: 'abc123', thread_id: 'def456', subject: 'A private subject', snippet: 'Private excerpt', reply_draft: 'Generated reply', reply_ai_generated: true) }
  before { sign_in user }

  it 'presents explicit setup and both languages without credentials' do
    allow(Messaging::GoogleOauth).to receive(:available?).and_return(false)
    get messaging_connection_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Gmail', 'not available')
    I18n.with_locale(:es) { get messaging_connection_path }
    expect(response.body).to include('no está disponible')
  end

  it 'never begins OAuth without the consent POST or exchanges an invalid callback' do
    expect(Messaging::GoogleOauth).not_to receive(:exchange)
    get callback_messaging_connection_path, params: { state: 'bad', code: 'secret' }
    expect(response).to redirect_to(messaging_connection_path)
    expect(Messaging::GoogleOauth).not_to receive(:authorization_url)
    post connect_messaging_connection_path
    expect(response).to redirect_to(messaging_connection_path)
  end

  it 'renders source-linked encrypted snippets and editable draft forms without sending controls' do
    context
    get messaging_connection_path
    expect(response.body).to include('A private subject', 'Private excerpt', context.source_url, 'Generated reply', 'Excluded from AI memory extraction')
    expect(response.body).not_to include('secret-access', 'secret-refresh', 'Send message')
    expect(response.headers['Cache-Control']).to include('no-store')
  end

  it 'exports safe communication context and clears only its draft during selective AI deletion' do
    context
    data = DataExports::Snapshot.new(user:).to_h.fetch('messaging_connection')
    expect(data.to_s).to include('Private excerpt', 'Generated reply', context.source_url)
    expect(data.to_s).not_to include('secret-access', 'secret-refresh', 'access_token', 'refresh_token')
    DataDeletions::DeleteAiData.call(user:)
    expect(context.reload.reply_draft).to be_nil
    expect(context.snippet).to eq('Private excerpt')
  end

  it 'prevents another owner from deleting or editing an imported source' do
    context
    foreign_user = create(:user)
    sign_in foreign_user
    delete delete_context_messaging_connection_path(context_id: context.id)
    expect(response).to have_http_status(:not_found)
    sign_in foreign_user
    patch edit_draft_messaging_connection_path(context_id: context.id), params: { reply_draft: 'Stolen', lock_version: 0 }
    expect(response).to have_http_status(:not_found)
    expect(context.reload.reply_draft).to eq('Generated reply')
  end

  it 'retains account and retry state when Gmail revocation fails' do
    context
    allow(Messaging::GoogleOauth).to receive(:revoke).and_raise(Messaging::Error)
    expect { DataDeletions::DeleteAccount.call(user:) }.to raise_error(DataDeletions::DeleteAccount::CalendarRevocationError)
    expect(user.reload).to be_persisted
    expect(connection.reload.status).to eq('cleanup_required')
  end
  it 'searches only on explicit submission and imports only the selected result' do
    connection.update!(token_expires_at: 1.hour.from_now)
    create(:automation_permission, user:, capability: 'access_messages', mode: 'ask_every_time')
    row = { external_id: 'abc123', thread_id: 'def456', subject: 'Subject', snippet: 'Selected snippet' }
    provider = instance_double(Messaging::Google, search: [ row ], message: row)
    allow(Messaging::Google).to receive(:new).and_return(provider)
    get messaging_connection_path
    expect(provider).not_to have_received(:search)
    expect { post search_messaging_connection_path, params: { messaging_query: 'from:friend@example.test' } }.not_to change(ImportedMessageContext, :count)
    expect(response.body).to include('Selected snippet', 'Import this excerpt')
    post import_messaging_connection_path, params: { external_id: 'abc123', approved: '1' }
    expect(connection.imported_message_contexts.count).to eq(1)
    expect(connection.imported_message_contexts.first.snippet).to eq('Selected snippet')
  end
end
