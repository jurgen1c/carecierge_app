require 'rails_helper'

RSpec.describe 'Messaging foundations' do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:connection) { MessagingConnection.create!(mailbox_email: 'secondary@example.com', user:, access_token: 'secret-access', refresh_token: 'secret-refresh', token_expires_at: 1.hour.from_now) }
  let(:row) { { external_id: 'abc123', thread_id: 'def456', subject: 'Private subject', snippet: 'A private message excerpt' } }

  before do
    create(:automation_permission, user:, capability: 'access_messages', mode: 'ask_every_time')
    create(:automation_permission, user:, capability: 'draft_messages', mode: 'ask_every_time')
  end

  it 'requires explicit import approval and current access permission' do
    provider = instance_double(Messaging::Google, message: row)
    connection
    expect(provider).not_to receive(:message)
    expect { Messaging::Import.call(user:, external_id: 'abc123', approved: false, provider:) }.to raise_error(Messaging::Error)
    user.automation_permissions.find_by!(capability: 'access_messages').update!(mode: 'disabled')
    expect { Messaging::Import.call(user:, external_id: 'abc123', approved: true, provider:) }.to raise_error(Messaging::Error)
  end

  it 'encrypts selected source context, deduplicates imports and keeps extraction excluded' do
    connection
    provider = instance_double(Messaging::Google, message: row)
    context = Messaging::Import.call(user:, external_id: 'abc123', approved: true, provider:)
    expect { Messaging::Import.call(user:, external_id: 'abc123', approved: true, provider:) }.not_to change(ImportedMessageContext, :count)
    expect(context.source_url).to include('authuser=secondary%40example.com', '#all/def456')
    expect(context.ai_memory_extraction_allowed?).to be(false)
    expect(context.read_attribute_before_type_cast(:snippet)).not_to include(row[:snippet])
    expect(AuditEvent.last.metadata).to eq('result' => 'imported')
    expect(AuditEvent.last.metadata.to_s).not_to include('Private')
  end

  it 'generates only an explicitly approved review draft and excludes vault context' do
    context = connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    expect(generator).to receive(:generate).with(hash_including(situation: include(row[:snippet]))).and_return('Review this reply')
    expect { Messaging::Draft.call(user:, context_id: context.id, expected_version: context.lock_version, approved: false, generator:) }.to raise_error(Messaging::Error)
    expect { Messaging::Draft.call(user:, context_id: context.id, expected_version: context.lock_version, approved: true, generator:) }.not_to change { ActionMailer::Base.deliveries.count }
    expect(context.reload.reply_draft).to eq('Review this reply')
    expect(context.read_attribute_before_type_cast(:reply_draft)).not_to include('Review this reply')
    expect(MessageDraft.count).to eq(0)
  end

  it 'rejects cross-owner context and profiles' do
    context = connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    foreign = create(:relationship_profile)
    create(:automation_permission, user: foreign.user, capability: 'draft_messages', mode: 'ask_every_time')
    expect { Messaging::Draft.call(user: foreign.user, context_id: context.id, expected_version: 0, approved: true) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { Messaging::DeleteContext.call(user: foreign.user, context_id: context.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'deletes local context independently of provider availability and permission' do
    context = connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    user.automation_permissions.update_all(mode: 'disabled')
    expect(Messaging::GoogleOauth).not_to receive(:revoke)
    expect { Messaging::DeleteContext.call(user:, context_id: context.id) }.to change(ImportedMessageContext, :count).by(-1)
  end

  it 'deletes imported context and retains only retry credentials when revocation fails' do
    connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    allow(Messaging::GoogleOauth).to receive(:revoke).and_raise(Messaging::Error)
    expect(Messaging::Disconnect.call(user:)).to be(false)
    expect(connection.reload.status).to eq('cleanup_required')
    expect(connection.imported_message_contexts).to be_empty
    allow(Messaging::GoogleOauth).to receive(:revoke).and_return(true)
    expect(Messaging::Disconnect.call(user:)).to be(true)
    expect(MessagingConnection.exists?(connection.id)).to be(false)
  end
  it 'does not feed imported snippets into ordinary relationship AI context' do
    connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    result = MessageDrafts::ContextBuilder.new(relationship_profile: profile).call
    expect(result.text).not_to include(row[:snippet], row[:subject])
    expect(ConversationRecap.count).to eq(0)
    expect(ExtractedMemory.count).to eq(0)
  end

  it 'rejects stale draft generation and edits without calling the provider' do
    context = connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    Messaging::EditDraft.call(user:, context_id: context.id, content: 'Owner revision', expected_version: 0)
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    expect(generator).not_to receive(:generate)
    expect { Messaging::Draft.call(user:, context_id: context.id, approved: true, expected_version: 0, generator:) }.to raise_error(Messaging::Error)
    expect { Messaging::EditDraft.call(user:, context_id: context.id, content: 'Old browser text', expected_version: 0) }.to raise_error(Messaging::Error)
    expect(context.reload.reply_draft).to eq('Owner revision')
  end
  it 'preserves manual-only replies when deleting AI-generated data' do
    context = connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    Messaging::EditDraft.call(user:, context_id: context.id, content: 'My own words', expected_version: 0)
    DataDeletions::DeleteAiData.call(user:)
    expect(context.reload.reply_draft).to eq('My own words')
  end
  it 'retains generated lineage after editing and clears it during selective AI deletion' do
    context = connection.imported_message_contexts.create!(**row, source_key: 'abc123')
    generator = instance_double(MessageDrafts::OpenAiGenerator, generate: 'AI reply')
    Messaging::Draft.call(user:, context_id: context.id, approved: true, expected_version: 0, generator:)
    Messaging::EditDraft.call(user:, context_id: context.id, content: 'Edited AI reply', expected_version: context.reload.lock_version)
    expect(context.reload.reply_ai_generated).to be(true)
    DataDeletions::DeleteAiData.call(user:)
    expect(context.reload.reply_draft).to be_nil
    expect(context.snippet).to eq(row[:snippet])
  end
end
