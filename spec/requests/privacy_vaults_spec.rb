require "rails_helper"

RSpec.describe "Privacy vaults", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password:, password_confirmation: password) }
  let(:relationship_profile) { create(:relationship_profile, user:, first_name: "Maya") }

  before { sign_in user }

  it "keeps protected content concealed on the relationship profile" do
    memory = create(
      :memory_record,
      relationship_profile:,
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )
    PrivacyVault::Protect.call(actor: user, protectable: memory)

    get relationship_profile_path(relationship_profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Privacy vault")
    expect(response.body).to include("1 protected item")
    expect(response.body).to include("Open vault")
    expect(response.body).not_to include("Private anniversary plan")
    expect(response.body).not_to include("Book the quiet table")
  end

  it "prevents Turbo from snapshotting decrypted vault content" do
    memory = create(
      :memory_record,
      relationship_profile:,
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }

    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response.body).to include("Private anniversary plan")
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(response.body).to include('<meta name="turbo-cache-control" content="no-cache">')
    expect(response.body).to include('data-controller="privacy-vault"')
    expect(response.body).to match(/data-privacy-vault-lease-duration-value="\d+"/)
  end

  it "does not render decrypted content when the authoritative lease touch fails" do
    memory = create(:memory_record, relationship_profile:, title: "Private plan", body: "Secret payload")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    allow_any_instance_of(PrivacyVaultsController).to receive(:privacy_vault_unlocked?).and_return(true)
    allow_any_instance_of(PrivacyVaultsController).to receive(:touch_privacy_vault_lease!).and_return(false)

    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Secret payload")
  end

  it "requires a valid password and records metadata-only unlock events" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: "wrong-password" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password was not accepted")
    expect(response.parsed_body.at_css("form[action='#{unlock_relationship_profile_privacy_vault_path(relationship_profile)}']")["data-action"])
      .to include("privacy-vault#lock")
    expect(VaultAccessEvent.recent_first.first).to have_attributes(event_type: "unlock_failed", user:)

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(relationship_profile))
    expect(VaultAccessEvent.recent_first.first).to have_attributes(event_type: "unlocked", user:)
    expect(VaultAccessEvent.recent_first.first.attributes.to_s).not_to include(password)
  end

  it "clears an active lease when another tab submits an invalid password" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: "wrong-password" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password was not accepted")
    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Unlocked for 10 minutes")
  end

  it "revokes an existing lease even when failed-unlock auditing errors" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    allow(VaultAccessEvent).to receive(:record!).and_wrap_original do |method, **attributes|
      raise ActiveRecord::RecordInvalid.new(VaultAccessEvent.new) if attributes[:event_type] == "unlock_failed"

      method.call(**attributes)
    end

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: "wrong-password" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password was not accepted")
    allow(VaultAccessEvent).to receive(:record!).and_call_original
    get relationship_profile_privacy_vault_path(relationship_profile)
    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Unlocked for 10 minutes")
  end

  it "uses an inactivity-based ten-minute lease and supports explicit locking" do
    Timecop.freeze(Time.zone.local(2026, 7, 16, 10, 0, 0)) do
      post unlock_relationship_profile_privacy_vault_path(relationship_profile),
        params: { privacy_vault_unlock: { password: } }
      get relationship_profile_privacy_vault_path(relationship_profile)
      expect(response.body).to include("Unlocked for 10 minutes")

      Timecop.travel(9.minutes.from_now)
      get relationship_profile_privacy_vault_path(relationship_profile)
      expect(response.body).to include("Unlocked for 10 minutes")

      Timecop.travel(2.minutes.from_now)
      get relationship_profile_privacy_vault_path(relationship_profile)
      expect(response.body).to include("Unlocked for 10 minutes")

      Timecop.travel(11.minutes.from_now)
      get relationship_profile_privacy_vault_path(relationship_profile)
      expect(response.body).to include("Enter your password")
    end

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    delete lock_relationship_profile_privacy_vault_path(relationship_profile)
    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response.body).to include("Enter your password")
    expect(VaultAccessEvent.where(event_type: "locked", user:)).to exist
  end

  it "does not accept a previously issued session cookie after explicit locking" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    session_key = Rails.application.config.session_options.fetch(:key)
    unlocked_cookie = response.cookies.fetch(session_key)

    delete lock_relationship_profile_privacy_vault_path(relationship_profile)
    cookies[session_key] = unlocked_cookie
    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Unlocked for 10 minutes")
  end

  it "revokes the lease even when recording the lock event fails" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    allow(VaultAccessEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(VaultAccessEvent.new))

    delete lock_relationship_profile_privacy_vault_path(relationship_profile)

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(relationship_profile))
    allow(VaultAccessEvent).to receive(:record!).and_call_original
    get relationship_profile_privacy_vault_path(relationship_profile)
    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Unlocked for 10 minutes")
  end

  it "does not accept a previously issued session cookie after sign out" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    session_key = Rails.application.config.session_options.fetch(:key)
    unlocked_cookie = response.cookies.fetch(session_key)

    delete destroy_user_session_path
    cookies[session_key] = unlocked_cookie
    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Unlocked for 10 minutes")
  end

  it "signs out before sending a signed-in user to password recovery" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    previous_lease_version = user.reload.privacy_vault_lease_version

    post reset_password_relationship_profile_privacy_vault_path(relationship_profile)

    expect(response).to redirect_to(new_user_password_path)
    expect(user.reload.privacy_vault_lease_version).to eq(previous_lease_version + 1)
    get relationship_profile_privacy_vault_path(relationship_profile)
    expect(response).to redirect_to(new_user_session_path)
  end

  it "invalidates an existing lease after the account password changes" do
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    user.update!(password: "new-password123", password_confirmation: "new-password123")

    get relationship_profile_privacy_vault_path(relationship_profile)
    expect(response).to redirect_to(new_user_session_path)

    sign_in user
    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Enter your password")
    expect(response.body).not_to include("Unlocked for 10 minutes")
  end

  it "revalidates the submitted password after acquiring the user lock" do
    replacement_digest = Devise::Encryptor.digest(User, "new-password123")
    allow_any_instance_of(User).to receive(:with_lock).and_wrap_original do |original, *, &block|
      original.receiver.update_column(:encrypted_password, replacement_digest)
      original.call(&block)
    end

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Password was not accepted")
  end

  it "records successful unlock auditing after releasing the user lock" do
    user_lock_held = false
    allow_any_instance_of(User).to receive(:with_lock).and_wrap_original do |method, *, &block|
      method.call do
        user_lock_held = true
        block.call
      ensure
        user_lock_held = false
      end
    end
    expect(VaultAccessEvent).to receive(:record!).with(hash_including(event_type: "unlocked")).and_wrap_original do |method, **attributes|
      expect(user_lock_held).to be(false)
      method.call(**attributes)
    end

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(relationship_profile))
  end

  it "keeps a successful unlock usable when access auditing fails" do
    allow(VaultAccessEvent).to receive(:record!).and_wrap_original do |method, **attributes|
      raise ActiveRecord::RecordInvalid.new(VaultAccessEvent.new) if attributes[:event_type] == "unlocked"

      method.call(**attributes)
    end

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(relationship_profile))
    allow(VaultAccessEvent).to receive(:record!).and_call_original
    get relationship_profile_privacy_vault_path(relationship_profile)
    expect(response.body).to include("Unlocked for 10 minutes")
  end

  it "renders decrypted content when view auditing fails" do
    memory = create(:memory_record, relationship_profile:, title: "Private plan", body: "Visible after unlock")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    allow(VaultAccessEvent).to receive(:record!).and_wrap_original do |method, **attributes|
      raise ActiveRecord::RecordInvalid.new(VaultAccessEvent.new) if attributes[:event_type] == "viewed"

      method.call(**attributes)
    end

    get relationship_profile_privacy_vault_path(relationship_profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Visible after unlock")
  end

  it "halts vault mutations when the authoritative check-and-touch fails" do
    memory = create(:memory_record, relationship_profile:, title: "Private plan", body: "Secret")
    allow_any_instance_of(PrivacyVaultItemsController).to receive(:privacy_vault_unlocked?).and_return(true)
    allow_any_instance_of(PrivacyVaultItemsController).to receive(:touch_privacy_vault_lease!).and_return(false)

    post relationship_profile_privacy_vault_items_path(relationship_profile),
      params: { privacy_vault_item: { protectable_type: "MemoryRecord", protectable_id: memory.id } }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(relationship_profile))
    expect(relationship_profile.privacy_vault_items).to be_empty
  end

  it "protects, reveals, changes suggestion preference, and restores an owned record only while unlocked" do
    memory = create(
      :memory_record,
      relationship_profile:,
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )

    post relationship_profile_privacy_vault_items_path(relationship_profile),
      params: { privacy_vault_item: { protectable_type: "MemoryRecord", protectable_id: memory.id } }
    expect(response).to redirect_to(relationship_profile_privacy_vault_path(relationship_profile))
    expect(relationship_profile.privacy_vault_items).to be_empty

    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    post relationship_profile_privacy_vault_items_path(relationship_profile),
      params: { privacy_vault_item: { protectable_type: "MemoryRecord", protectable_id: memory.id } }

    item = relationship_profile.privacy_vault_items.reload.sole
    get relationship_profile_privacy_vault_path(relationship_profile)
    expect(response.body).to include("Private anniversary plan")
    expect(response.body).to include("Excluded from suggestions")

    patch relationship_profile_privacy_vault_item_path(relationship_profile, item),
      params: { privacy_vault_item: { suggestion_usage: "allowed" } }
    expect(item.reload).to be_suggestion_allowed

    delete relationship_profile_privacy_vault_item_path(relationship_profile, item)

    expect(memory.reload).to have_attributes(
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )
    expect(VaultAccessEvent.where(event_type: %w[protected suggestion_usage_changed restored], user:).count).to eq(3)
  end

  it "rolls back a suggestion preference change when its audit event cannot be recorded" do
    memory = create(:memory_record, relationship_profile:, title: "Private plan", body: "Secret")
    item = PrivacyVault::Protect.call(actor: user, protectable: memory)
    post unlock_relationship_profile_privacy_vault_path(relationship_profile),
      params: { privacy_vault_unlock: { password: } }
    allow(VaultAccessEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(VaultAccessEvent.new))

    patch relationship_profile_privacy_vault_item_path(relationship_profile, item),
      params: { privacy_vault_item: { suggestion_usage: "allowed" } }

    expect(item.reload).not_to be_suggestion_allowed
  end

  it "does not expose another user's vault" do
    other_profile = create(:relationship_profile)

    get relationship_profile_privacy_vault_path(other_profile)

    expect(response).to have_http_status(:not_found)
  end

  it "does not allow ordinary profile updates to overwrite protected note or detail payloads" do
    note = create(:relationship_note, relationship_profile:, body: "Private family concern")
    detail = create(
      :relationship_field_value,
      relationship_profile:,
      template_field: nil,
      custom: true,
      label: "Family context",
      value: "Sensitive detail"
    )
    note_item = PrivacyVault::Protect.call(actor: user, protectable: note)
    detail_item = PrivacyVault::Protect.call(actor: user, protectable: detail)

    patch relationship_profile_path(relationship_profile), params: {
      relationship_profile: {
        relationship_notes_attributes: {
          "0" => { id: note.id, body: "Bypassed note", _destroy: "1" }
        },
        relationship_field_values_attributes: {
          "0" => { id: detail.id, label: "Bypassed label", value: "Bypassed detail", _destroy: "1" }
        }
      }
    }

    expect(response).to redirect_to(relationship_profile_path(relationship_profile))
    expect(note.reload).to be_persisted
    expect(detail.reload).to be_persisted
    expect(note_item.reload.payload.fetch("body")).to include("Private family concern")
    expect(detail_item.reload.payload).to include("title" => "Family context", "body" => "Sensitive detail")
  end

  it "does not return a profile when the only search match is a protected note" do
    note = create(:relationship_note, relationship_profile:, body: "Only secret garden phrase")
    PrivacyVault::Protect.call(actor: user, protectable: note)

    get relationship_profiles_path,
      params: { q: { RelationshipProfile::SearchQuery::SEARCH_PREDICATE => "secret garden" } }

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(relationship_profile.full_name)
  end

  it "renders the password boundary and vault controls in Spanish" do
    I18n.with_locale(:es) do
      get relationship_profile_privacy_vault_path(relationship_profile)
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Bóveda de privacidad")
    expect(response.body).to include("Ingresa tu contraseña")
    expect(response.body).not_to include("Translation missing")
  end
end
