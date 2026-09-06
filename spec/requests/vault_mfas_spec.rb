require "rails_helper"

RSpec.describe "Vault MFA", type: :request do
  let(:password) { "known-password123" }
  let(:user) { create(:user, password:) }
  let(:profile) { create(:relationship_profile, user:) }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 5, 12)) { example.run } }
  before { sign_in user }

  def enroll
    post vault_mfa_path, params: { vault_mfa: { password: } }
    expect(response).to have_http_status(:ok)
    secret = user.reload.vault_mfa_credential.totp_secret
    post prove_vault_mfa_path, params: { vault_mfa: { code: ROTP::TOTP.new(secret).now } }
    expect(response).to have_http_status(:ok)
    codes = response.parsed_body.css("li code").map(&:text)
    post complete_vault_mfa_path, params: { vault_mfa: { acknowledged: "1" } }
    expect(response).to redirect_to(vault_mfa_path)
    [ secret, codes ]
  end

  it "requires password, authenticator proof, and acknowledgement; displays recovery codes only once" do
    post vault_mfa_path, params: { vault_mfa: { password: "wrong" } }
    expect(response).to have_http_status(:unprocessable_content)
    post vault_mfa_path, params: { vault_mfa: { password: } }
    expect(response.body).to include("data:image/svg+xml;base64,")
    secret = user.reload.vault_mfa_credential.totp_secret
    expect(response.body).to include(secret)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).to include('name="turbo-cache-control" content="no-cache"')
    post complete_vault_mfa_path, params: { vault_mfa: { acknowledged: "1" } }
    expect(response).to have_http_status(:unprocessable_content)
    post prove_vault_mfa_path, params: { vault_mfa: { code: ROTP::TOTP.new(secret).now } }
    codes = response.parsed_body.css("li code").map(&:text)
    expect(codes.size).to eq(10)
    expect(user.reload).not_to be_vault_mfa_enabled
    expect(response.body).not_to include(secret)
    post complete_vault_mfa_path, params: { vault_mfa: { acknowledged: "0" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload).not_to be_vault_mfa_enabled
    post complete_vault_mfa_path, params: { vault_mfa: { acknowledged: "1" } }
    expect(user.reload).to be_vault_mfa_enabled
    get vault_mfa_path
    expect(response.body).not_to include(secret, *codes)
    post prove_vault_mfa_path, params: { vault_mfa: { code: ROTP::TOTP.new(secret).now } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include(secret, *codes)
  end

  it "preserves the configured authenticator after a rejected proof so a fresh code can be retried" do
    post vault_mfa_path, params: { vault_mfa: { password: } }
    secret = user.reload.vault_mfa_credential.totp_secret
    post prove_vault_mfa_path, params: { vault_mfa: { code: "invalid" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.at_css("form[action='#{prove_vault_mfa_path}']")).to be_present
    expect(response.body).not_to include(secret)
    expect(user.reload.vault_mfa_credential.totp_secret).to eq(secret)
    post prove_vault_mfa_path, params: { vault_mfa: { code: ROTP::TOTP.new(secret).now } }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.css("li code").size).to eq(10)
    expect(user.reload.vault_mfa_credential.totp_secret).to eq(secret)
  end

  it "keeps the vault locked when either factor is missing, wrong, expired, or replayed" do
    secret, = enroll
    endpoint = unlock_relationship_profile_privacy_vault_path(profile)
    code = ROTP::TOTP.new(secret).now
    post endpoint, params: { privacy_vault_unlock: { password:, code: } }
    expect(response).to have_http_status(:unprocessable_content) # enrollment code is consumed
    Timecop.travel(30.seconds.from_now)
    code = ROTP::TOTP.new(secret).now
    post endpoint, params: { privacy_vault_unlock: { password: "wrong", code: } }
    expect(response).to have_http_status(:unprocessable_content)
    post endpoint, params: { privacy_vault_unlock: { password: } }
    expect(response).to have_http_status(:unprocessable_content)
    post endpoint, params: { privacy_vault_unlock: { password:, code: ROTP::TOTP.new(secret).at(61.seconds.ago) } }
    expect(response).to have_http_status(:unprocessable_content)
    post endpoint, params: { privacy_vault_unlock: { password:, code: } }
    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    get relationship_profile_privacy_vault_path(profile)
    expect(response.body).to include("Unlocked for 10 minutes")
  end

  it "consumes recovery codes once and requires fresh TOTP to regenerate them" do
    secret, codes = enroll
    endpoint = unlock_relationship_profile_privacy_vault_path(profile)
    post endpoint, params: { privacy_vault_unlock: { password:, code: codes.first } }
    expect(response).to have_http_status(:redirect)
    post endpoint, params: { privacy_vault_unlock: { password:, code: codes.first } }
    expect(response).to have_http_status(:unprocessable_content)
    post regenerate_vault_mfa_path, params: { vault_mfa: { password:, code: codes.second } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.vault_mfa_credential.recovery_code_digests.size).to eq(9)
    Timecop.travel(30.seconds.from_now)
    post regenerate_vault_mfa_path, params: { vault_mfa: { password:, code: ROTP::TOTP.new(secret).now } }
    new_codes = response.parsed_body.css("li code").map(&:text)
    expect(new_codes.size).to eq(10)
    expect(new_codes & codes).to be_empty
    post endpoint, params: { privacy_vault_unlock: { password:, code: codes.second } }
    expect(response).to have_http_status(:unprocessable_content)
    post endpoint, params: { privacy_vault_unlock: { password:, code: new_codes.first } }
    expect(response).to have_http_status(:redirect)
  end

  it "uses an explicit password plus recovery-code lost-device path and revokes prior leases" do
    _, codes = enroll
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password:, code: codes.first } }
    key = Rails.application.config.session_options.fetch(:key)
    old_cookie = response.cookies.fetch(key)
    delete vault_mfa_path, params: { vault_mfa: { password: "wrong", code: codes.second } }
    expect(user.reload).to be_vault_mfa_enabled
    delete vault_mfa_path, params: { vault_mfa: { password:, code: codes.second } }
    expect(user.reload).not_to be_vault_mfa_enabled
    expect(user.vault_mfa_credential.totp_secret).to be_nil
    expect(user.vault_mfa_credential.recovery_code_digests).to be_empty
    cookies[key] = old_cookie
    get relationship_profile_privacy_vault_path(profile)
    expect(response.body).not_to include("Unlocked for 10 minutes")
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: } }
    expect(response).to have_http_status(:redirect)
  end

  it "does not let password recovery or ordinary OAuth sign-in bypass MFA" do
    _, codes = enroll
    post reset_password_vault_mfa_path
    expect(response).to redirect_to(new_user_password_path)
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("form[action='#{user_password_path}']")).to be_present
    expect(user.reload).to be_vault_mfa_enabled
    user.reset_password("replacement123", "replacement123")
    sign_in user
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: "replacement123" } }
    expect(response).to have_http_status(:unprocessable_content)
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: "replacement123", code: codes.first } }
    expect(response).to have_http_status(:redirect)
  end

  it "requires an OAuth-created account to know its Carecierge password before setup" do
    user.update!(provider: "google_oauth2", uid: "test-oauth-user", password: Devise.friendly_token, password_confirmation: nil)
    sign_in user
    post vault_mfa_path, params: { vault_mfa: { password: } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.vault_mfa_credential.totp_secret).to be_nil
    expect(response.body).to include("establish a password through password recovery")
    user.reset_password(password, password)
    sign_in user
    post vault_mfa_path, params: { vault_mfa: { password: } }
    expect(response).to have_http_status(:ok)
    expect(user.reload.vault_mfa_credential.totp_secret).to be_present
  end

  it "rejects cross-user enrollment proof and cross-user vault access" do
    post vault_mfa_path, params: { vault_mfa: { password: } }
    secret = user.reload.vault_mfa_credential.totp_secret
    other = create(:user, password:)
    sign_in other
    post prove_vault_mfa_path, params: { vault_mfa: { code: ROTP::TOTP.new(secret).now, user_id: user.id } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload).not_to be_vault_mfa_enabled
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password: } }
    expect(response).to have_http_status(:not_found)
  end

  it "enforces an account-wide budget across unlock, enrollment and management" do
    secret, = enroll
    5.times { post regenerate_vault_mfa_path, params: { vault_mfa: { password:, code: "000000" } } }
    expect(user.reload.vault_mfa_credential).to be_rate_limited
    Timecop.travel(30.seconds.from_now)
    delete vault_mfa_path, params: { vault_mfa: { password:, code: ROTP::TOTP.new(secret).now } }
    expect(response.body).to include("Too many attempts")
    expect(user.reload).to be_vault_mfa_enabled
    Timecop.travel(5.minutes.from_now)
    delete vault_mfa_path, params: { vault_mfa: { password:, code: ROTP::TOTP.new(secret).now } }
    expect(user.reload).not_to be_vault_mfa_enabled
  end

  it "records security lifecycle events without credentials or protected content" do
    secret, codes = enroll
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password:, code: "wrong" } }
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { password:, code: codes.first } }
    delete vault_mfa_path, params: { vault_mfa: { password:, code: codes.second } }
    events = user.audit_events.where("action LIKE 'privacy_vault.%'")
    expect(events.pluck(:action)).to include("privacy_vault.mfa_enrolled", "privacy_vault.mfa_verified", "privacy_vault.mfa_verification_failed", "privacy_vault.recovery_used", "privacy_vault.mfa_disabled")
    expect(events.map(&:attributes).to_s).not_to include(password, secret, *codes)
    expect(events.pluck(:metadata)).to all(eq({}))
  end

  it "renders accessible English and Spanish setup and lost-device guidance" do
    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        get vault_mfa_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("vault_mfa.title"), I18n.t("vault_mfa.no_recovery"))
        expect(response.body).not_to include("Translation missing")
        expect(response.parsed_body.at_css("label[for='vault_mfa_password']")).to be_present
        expect(response.parsed_body.at_css("#vault-mfa-error[role='alert']")).to be_present
      end
    end
  end

  it "rejects missing verification fields without creating a lease or raising" do
    post vault_mfa_path
    expect(response).to have_http_status(:unprocessable_content)
    post unlock_relationship_profile_privacy_vault_path(profile), params: { privacy_vault_unlock: { code: "123456" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload).not_to be_vault_mfa_enabled
  end

  it "returns an error for management when MFA is not configured" do
    post regenerate_vault_mfa_path, params: { vault_mfa: { password:, code: "123456" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Authenticator security is not enabled")
    delete vault_mfa_path, params: { vault_mfa: { password:, code: "123456" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Authenticator security is not enabled")
  end

  it "requires sign-in for every vault-security action" do
    sign_out user
    get vault_mfa_path
    expect(response).to redirect_to(new_user_session_path)
    post vault_mfa_path, params: { vault_mfa: { password: } }
    expect(response).to redirect_to(new_user_session_path)
  end
end
