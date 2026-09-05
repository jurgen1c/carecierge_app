require 'rails_helper'

RSpec.describe Contacts::Decide do
  let(:user) { create(:user) }
  let(:connection) { ContactsConnection.create!(user:, status: 'connected', access_token: 'secret') }
  let(:contact) { connection.imported_contacts.create!(provider_key: 'key', external_id: 'people/1', data: { 'first_name' => 'Elena', 'last_name' => 'Ruiz', 'email' => 'elena@example.com', 'phone' => '5550100', 'birthday' => '1990-05-04' }) }

  before { allow(AutomationPermission).to receive(:decision_for).and_return(AutomationPermissionDecision.new(capability: AutomationCapability.fetch('access_contacts'), mode: 'ask_every_time')) }

  def decide(choice, **options)
    described_class.call(contact:, actor: user, choice:, expected_version: contact.reload.lock_version, **options)
  end

  it 'stages private contacts without creating profiles' do
    expect { contact }.not_to change(RelationshipProfile, :count)
    expect(contact.reload.data['email']).to eq('elena@example.com')
    expect(contact.attributes_before_type_cast['data']).not_to include('elena@example.com')
  end

  it 'imports only on an explicit create and makes repeated requests harmless' do
    expect { decide('create') }.to change(RelationshipProfile, :count).by(1)
    profile = contact.reload.relationship_profile
    expect([ profile.full_name, profile.email, profile.phone, profile.birthday.iso8601 ]).to eq([ 'Elena Ruiz', 'elena@example.com', '5550100', '1990-05-04' ])
    expect(profile.profile_attributes.fetch('contacts_sources').first.fetch('provider')).to eq('google_contacts')
    expect { decide('create') }.not_to change(RelationshipProfile, :count)
    expect(user.audit_events.last.metadata.to_s).not_to include('Elena', 'elena@example.com')
  end

  it 'links an explicit match without overwriting and undoes the link' do
    profile = create(:relationship_profile, user:, first_name: 'Existing')
    decide('link', profile_id: profile.id)
    expect(profile.reload.first_name).to eq('Existing')
    decide('undo')
    expect(contact.reload.relationship_profile).to be_nil
    expect(profile.reload).to be_kept
  end

  it 'rejects another owners profile' do
    profile = create(:relationship_profile)
    expect { decide('link', profile_id: profile.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it 'requires an explicit duplicate override before creating another matching profile' do
    create(:relationship_profile, user:, first_name: 'Elena', last_name: 'Ruiz')
    expect { decide('create') }.to raise_error(Contacts::Error)
    expect { decide('create', allow_duplicate: true) }.to change(RelationshipProfile, :count).by(1)
  end

  it 'archives a created profile on undo while preserving later edits' do
    decide('create')
    profile = contact.reload.relationship_profile
    profile.update!(first_name: 'My edit')
    decide('undo')
    expect(profile.reload).to be_discarded
    expect(profile.first_name).to eq('My edit')
  end

  it 'refreshes staged data separately and applies only explicitly reviewed updates' do
    decide('create')
    profile = contact.reload.relationship_profile
    contact.update!(data: contact.data.merge('first_name' => 'New name'))
    expect(profile.reload.first_name).to eq('Elena')
    decide('update')
    expect(profile.reload.first_name).to eq('New name')
    decide('undo')
    expect(profile.reload.first_name).to eq('Elena')
  end

  it 'refuses to overwrite local changes with a provider update' do
    decide('create')
    contact.reload.relationship_profile.update!(first_name: 'My edit')
    expect { decide('update') }.to raise_error(Contacts::Error)
  end

  it 'rejects stale review submissions and disabled permission' do
    version = contact.lock_version
    contact.update!(data: contact.data.merge('first_name' => 'Changed'))
    expect { described_class.call(contact:, actor: user, choice: 'create', expected_version: version) }.to raise_error(Contacts::Error)
    allow(AutomationPermission).to receive(:decision_for).and_return(AutomationPermissionDecision.new(capability: AutomationCapability.fetch('access_contacts'), mode: 'disabled'))
    expect { decide('create') }.to raise_error(Contacts::Error)
  end
  it 'persists contact-method changes and removals, then restores them on undo' do
    decide('create')
    profile = contact.reload.relationship_profile
    contact.update!(data: contact.data.merge('email' => 'new@example.com', 'phone' => nil))
    decide('update')
    expect(profile.reload.email).to eq('new@example.com')
    expect(profile.reload.phone).to be_nil
    decide('undo')
    expect(profile.reload.email).to eq('elena@example.com')
    expect(profile.reload.phone).to eq('5550100')
  end

  it 'preserves original create reversal after undoing a later update' do
    decide('create')
    profile = contact.reload.relationship_profile
    contact.update!(data: contact.data.merge('first_name' => 'Changed'))
    decide('update')
    decide('undo')
    expect(contact.reload.decision).to eq('create')
    decide('undo')
    expect(profile.reload).to be_discarded
  end

  it 'permits a new explicit import after the earlier profile was permanently removed' do
    decide('create')
    contact.reload.relationship_profile.destroy!
    expect { decide('create') }.to change(RelationshipProfile, :count).by(1)
  end
  it 'erases locally authored snapshots on permanent deletion while retaining independently fetched data' do
    profile = create(:relationship_profile, user:, first_name: 'Private authored name')
    profile.contact_methods.create!(kind: 'email', value: 'private-authored@example.com')
    decide('link', profile_id: profile.id)
    decide('update')
    version = contact.reload.lock_version
    expect(contact.previous_data.to_json).to include('Private authored name', 'private-authored@example.com')

    DataDeletions::Perform.call(user:, request_kind: 'relationship_profile', subject: profile) { profile.with_lock { profile.destroy! } }

    expect(contact.reload.relationship_profile_id).to be_nil
    expect(contact.applied_data).to be_nil
    expect(contact.previous_data).to be_nil
    expect(contact.decision).to eq('pending')
    expect(contact.lock_version).to be > version
    expect(contact.data['email']).to eq('elena@example.com')
    expect(DataExports::Snapshot.new(user:).to_h.to_json).not_to include('Private authored name', 'private-authored@example.com')
    expect { described_class.call(contact:, actor: user, choice: 'create', expected_version: version) }.to raise_error(Contacts::Error)
    expect { decide('create') }.to change(RelationshipProfile, :count).by(1)
  end

  it 'imports phones into the existing profile edit form' do
    decide('create')
    profile = contact.reload.relationship_profile
    expect(RelationshipProfiles::FormState.new(profile.reload).contact_method_for('personal_phone').value).to eq('5550100')
  end

  it 'restores the identity, label and preference of removed contact methods' do
    profile = create(:relationship_profile, user:)
    method = profile.contact_methods.create!(kind: 'email', value: 'mine@example.com', label: 'Family', preferred: true)
    decide('link', profile_id: profile.id)
    contact.update!(data: contact.data.merge('email' => nil))
    decide('update')
    expect(profile.contact_methods.reload.find_by(kind: 'email')).to be_nil
    decide('undo')
    restored = profile.contact_methods.reload.find_by(kind: 'email')
    expect(restored.attributes.slice('id', 'value', 'label', 'preferred')).to eq(method.attributes.slice('id', 'value', 'label', 'preferred'))
  end
  it 'preserves the real undo snapshot when the same update is applied again' do
    decide('create')
    profile = contact.reload.relationship_profile
    contact.update!(data: contact.data.merge('first_name' => 'Changed'))
    decide('update')
    prior = contact.reload.previous_data
    expect { decide('update') }.not_to change(AuditEvent, :count)
    expect(contact.reload.previous_data).to eq(prior)
    decide('undo')
    expect(profile.reload.first_name).to eq('Elena')
  end
  it 'honors an enabled profile override when the account default is disabled' do
    allow(AutomationPermission).to receive(:decision_for).and_call_original
    profile = create(:relationship_profile, user:)
    AutomationPermission.create!(user:, relationship_profile: profile, capability: 'access_contacts', mode: 'ask_every_time')
    expect { decide('link', profile_id: profile.id) }.not_to raise_error
    expect(contact.reload.relationship_profile_id).to eq(profile.id)
  end
  it 'blocks create and fetch with disabled account access while allowing skip' do
    allow(AutomationPermission).to receive(:decision_for).and_call_original
    expect { decide('create') }.to raise_error(Contacts::Error) { |error| expect(error.code).to eq('permission_required') }
    expect(Contacts::Google).not_to receive(:new)
    expect { Contacts::Refresh.call(user:) }.to raise_error(Contacts::Error) { |error| expect(error.code).to eq('permission_required') }
    expect { decide('skip') }.not_to raise_error
  end

  it 'uses a disabled profile override for updates even with enabled account access and still permits undo' do
    allow(AutomationPermission).to receive(:decision_for).and_call_original
    AutomationPermission.create!(user:, capability: 'access_contacts', mode: 'ask_every_time')
    profile = create(:relationship_profile, user:)
    decide('link', profile_id: profile.id)
    AutomationPermission.create!(user:, relationship_profile: profile, capability: 'access_contacts', mode: 'disabled')
    expect { decide('update') }.to raise_error(Contacts::Error) { |error| expect(error.code).to eq('permission_required') }
    expect { decide('undo') }.not_to raise_error
    expect(contact.reload.relationship_profile_id).to be_nil
  end
end
