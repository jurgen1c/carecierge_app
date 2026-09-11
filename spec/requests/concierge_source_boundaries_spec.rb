require "rails_helper"

RSpec.describe 'Concierge source and session boundaries', type: :request do
  let(:user) { create(:user, onboarding_skipped_at: Time.current) }
  let(:profile) { create(:relationship_profile, user: user) }
  let(:conversation) { ConciergeConversation.create!(user: user, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(content: 'Review these records', locale: 'en', request_key: SecureRandom.uuid, context: Concierge::Context.capture(user: user, conversation: conversation)) }
  let(:token) { turn.claim! }

  it "retains the selected person beyond the bounded initial relationship choices" do
    100.times { |index| create(:relationship_profile, user:, first_name: "Alpha #{index}", preferred_name: nil) }
    profile.update!(first_name: "Zulu", preferred_name: nil)
    sign_in user
    [ concierge_conversations_path(relationship_profile_id: profile.id), concierge_conversation_path(conversation) ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      selects = Nokogiri::HTML(response.body).css('select[name$="[relationship_profile_id]"], select[name="relationship_profile_id"]')
      expect(selects).not_to be_empty
      selects.each do |select|
        expect(select.css('option[selected]').map { |option| option['value'] }).to include(profile.id)
        expect(select.css('option[value]').reject { |option| option['value'].blank? }.size).to be <= 101
      end
    end
  end
  def execute(name, arguments = {})
    Concierge::Execute.call(turn: turn, token: token, name: name, arguments: arguments)
  end

  it 'keeps history usable after deleting a quote with a previously read reminder' do
    plan = create(:event_plan, user: user, relationship_profile: profile)
    quote = create(:vendor_quote, user: user, event_plan: plan, vendor: create(:vendor, user: user))
    reminder = create(:reminder, user: user, relationship_profile: profile, event_plan: plan, vendor_quote: quote)
    execute('reminders.read', id: reminder.id)
    execute('quotes.destroy', event_plan_id: plan.id, id: quote.id)
    action = turn.actions.find_by!(name: 'quotes.destroy')
    Concierge::Decide.call(user: user, action: action, decision: 'approve', fingerprint: action.fingerprint)
    expect(reminder.reload.vendor_quote_id).to be_nil
    expect(Concierge::History.sources_current?(turn.reload)).to eq(true)
  end

  it 'keeps a read cadence current after an interaction changes through chat' do
    create(:contact_cadence, relationship_profile: profile)
    interaction = create(:interaction, relationship_profile: profile, occurred_at: 2.days.ago)
    execute('cadence.read')
    execute('interactions.update', id: interaction.id, occurred_at: 1.hour.ago.iso8601)
    expect(Concierge::History.sources_current?(turn.reload)).to eq(true)
  end

  it 'invalidates a cadence receipt when its derived last interaction changes' do
    create(:contact_cadence, relationship_profile: profile)
    interaction = create(:interaction, relationship_profile: profile, occurred_at: 2.days.ago)
    execute('cadence.read')
    interaction.update!(occurred_at: 1.hour.ago)
    expect(Concierge::History.sources_current?(turn.reload)).to eq(false)
  end

  it 'requires a session unlock before approving or retrying a vault-scoped turn' do
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: 'allowed')
    turn.update!(context: Concierge::Context.capture(user: user, conversation: conversation,
      selections: { 'vault_item_ids' => [ item.id ] }, vault_lease: PrivacyVault::Lease.issue_for(user)))
    commitment = create(:commitment, relationship_profile: profile)
    execute('commitments.destroy', id: commitment.id)
    action = turn.actions.find_by!(name: 'commitments.destroy')
    sign_in user
    patch concierge_conversation_concierge_action_path(conversation, action),
      params: { decision: 'approve', fingerprint: action.fingerprint }
    expect(action.reload.state).to eq('awaiting_approval')
    expect(Commitment.exists?(commitment.id)).to be(true)
    turn.fail!(token: token, error_code: 'provider_unavailable')
    expect {
      post retry_concierge_conversation_concierge_turn_path(conversation, turn)
    }.not_to have_enqueued_job(ConciergeResponseJob)
    expect(turn.reload.state).to eq('failed')
  end

  it "hides legacy protected first-message titles in locked conversation history" do
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    turn.update!(context: Concierge::Context.capture(user:, conversation:,
      selections: { "vault_item_ids" => [ item.id ] }, vault_lease: PrivacyVault::Lease.issue_for(user)))
    conversation.update!(title: "PROTECTED_HISTORY_TITLE")
    sign_in user
    get concierge_conversations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("PROTECTED_HISTORY_TITLE")
  end

  it "hides a private-context title after its selected note moves into the vault" do
    note = profile.relationship_notes.create!(body: "Sensitive wording", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    conversation.update!(title: "PRIVATE_HISTORY_TITLE")
    sign_in user
    get concierge_conversations_path
    expect(response.body).to include("PRIVATE_HISTORY_TITLE")
    PrivacyVault::Protect.call(actor: user, protectable: note)
    get concierge_conversations_path
    expect(response.body).not_to include("PRIVATE_HISTORY_TITLE")
  end

  it "provides bounded later private-note choices with full-page fallback and owner isolation" do
    notes = 21.times.map { |index| profile.relationship_notes.create!(body: "Private choice #{index}", private: true) }
    sign_in user
    get concierge_conversation_path(conversation, locale: :es)
    expect(response.body).to include("Mostrar más notas privadas")
    get concierge_conversation_path(conversation), params: { private_notes_page: 2, context_kind: "private_notes" },
      headers: { "Turbo-Frame" => "concierge_private_notes_2" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(notes.last.id)
    expect(response.body).not_to include(notes.first.id)
    expect(Nokogiri::HTML(response.body).css('input[type="checkbox"]').size).to eq(1)
    get concierge_conversations_path, params: { relationship_profile_id: profile.id, private_notes_page: 2 }
    expect(response.body).to include(notes.last.id)
    foreign = create(:relationship_profile)
    get concierge_conversations_path, params: { relationship_profile_id: foreign.id, private_notes_page: 2, context_kind: "private_notes" },
      headers: { "Turbo-Frame" => "concierge_private_notes_2" }
    expect(response).to have_http_status(:not_found)
  end

  it "requires the current vault session for later protected choices and rejects work-mode private selectors" do
    items = 21.times.map { create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed") }
    sign_in user
    get concierge_conversation_path(conversation), params: { vault_items_page: 2, context_kind: "vault_items" },
      headers: { "Turbo-Frame" => "concierge_vault_items_2" }
    expect(response).to have_http_status(:forbidden)
    password = SecureRandom.base64(24)
    user.update!(password:, password_confirmation: password)
    sign_in user
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: } }
    get concierge_conversation_path(conversation), params: { vault_items_page: 2, context_kind: "vault_items" },
      headers: { "Turbo-Frame" => "concierge_vault_items_2" }
    expect(response.body).to include(items.last.id)
    expect(response.body).not_to include(items.first.id)
    profile.update!(relationship_mode: "professional")
    get concierge_conversation_path(conversation), params: { private_notes_page: 1, context_kind: "private_notes" },
      headers: { "Turbo-Frame" => "concierge_private_notes_1" }
    expect(response).to have_http_status(:forbidden)
  end

  it "does not copy a protected first message into a new conversation title" do
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    Concierge::Submit.call(user:, conversation:, content: "PROTECTED_FIRST_MESSAGE", request_key: SecureRandom.uuid,
      locale: "en", context: { vault_item_ids: [ item.id ] }, vault_lease: PrivacyVault::Lease.issue_for(user))
    expect(conversation.reload.title).not_to include("PROTECTED_FIRST_MESSAGE")
  end

  it 'requires a vault-unlocked browser before showing protected conversational replies' do
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: 'allowed')
    turn.update!(context: Concierge::Context.capture(user: user, conversation: conversation,
      selections: { 'vault_item_ids' => [ item.id ] }, vault_lease: PrivacyVault::Lease.issue_for(user)))
    turn.update!(content: 'PROTECTED_VAULT_REQUEST')
    turn.finish!(token: token, response: 'PROTECTED_VAULT_REPLY')
    sign_in user
    get concierge_conversation_path(conversation)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('PROTECTED_VAULT_REPLY', 'PROTECTED_VAULT_REQUEST')
    get transcript_concierge_conversation_path(conversation)
    expect(response.body).not_to include('PROTECTED_VAULT_REPLY', 'PROTECTED_VAULT_REQUEST')
    password = SecureRandom.base64(24)
    user.update!(password: password, password_confirmation: password)
    # Refresh the stored worker lease after the password change invalidates old leases.
    snapshot = turn.context.merge('vault_lease' => PrivacyVault::Lease.issue_for(user.reload).to_session)
    turn.update!(context: snapshot)
    sign_in user
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: password } }
    get concierge_conversation_path(conversation)
    expect(response.body).to include('PROTECTED_VAULT_REPLY', 'PROTECTED_VAULT_REQUEST')
  end

  it "restores authorized protected history after reauthentication without renewing execution consent" do
    Timecop.freeze do
      password = SecureRandom.base64(24)
      user.update!(password:, password_confirmation: password)
      item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
      turn.update!(context: Concierge::Context.capture(user:, conversation:,
        selections: { "vault_item_ids" => [ item.id ] }, vault_lease: PrivacyVault::Lease.issue_for(user)))
      create(:automation_permission, user:, capability: "draft_messages", mode: "allow_automatically")
      allow_any_instance_of(MessageDrafts::OpenAiGenerator).to receive(:generate).and_return("PROTECTED_DRAFT_RECEIPT")
      expect(execute("drafts.generate", draft_type: "check_in", tone: "warm")).to include("status" => "succeeded")
      commitment = create(:commitment, relationship_profile: profile)
      execute("commitments.destroy", id: commitment.id)
      pending = turn.actions.find_by!(name: "commitments.destroy")
      turn.finish!(token:, response: "PROTECTED_HISTORY_REPLY")
      stored_context = turn.reload.context.deep_dup
      Timecop.travel(11.minutes.from_now) do
        sign_in user
        get concierge_conversation_path(conversation)
        expect(response.body).not_to include("PROTECTED_HISTORY_REPLY", "PROTECTED_DRAFT_RECEIPT")
        post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: } }
        [ concierge_conversation_path(conversation), transcript_concierge_conversation_path(conversation) ].each do |path|
          get path
          expect(response.body).to include("PROTECTED_HISTORY_REPLY", "PROTECTED_DRAFT_RECEIPT")
        end
        expect(turn.reload.context).to eq(stored_context)
        expect(Concierge::Decide.available?(user:, action: pending)).to be(false)
        patch concierge_conversation_concierge_action_path(conversation, pending),
          params: { decision: "approve", fingerprint: pending.fingerprint }
        expect(Commitment.exists?(commitment.id)).to be(true)
        item.update!(suggestion_usage: "excluded")
        get concierge_conversation_path(conversation)
        expect(response.body).not_to include("PROTECTED_HISTORY_REPLY", "PROTECTED_DRAFT_RECEIPT")
      end
    end
  end
end
