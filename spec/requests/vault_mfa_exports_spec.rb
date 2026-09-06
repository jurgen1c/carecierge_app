require "rails_helper"

RSpec.describe "Vault MFA sensitive exports", type: :request do
  let(:password) { "known-password123" }
  let(:user) { create(:user, password:) }
  let!(:credential) { create(:vault_mfa_credential, user:) }
  let!(:profile) { create(:relationship_profile, user:) }
  let(:export) { { scope: "account", format: "json", include_sensitive: "1", current_password: password } }

  before do
    memory = create(:memory_record, relationship_profile: profile, body: "Private exported content")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    sign_in user
  end

  it "requires a fresh factor even with a correct or reset password" do
    post data_exports_path, params: { data_export: export }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include("Private exported content")

    user.update!(password: "replacement-password123", password_confirmation: "replacement-password123")
    sign_in user.reload
    post data_exports_path, params: { data_export: export.merge(current_password: "replacement-password123") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include("Private exported content")
  end

  it "exports protected values with a fresh authenticator code and rejects replay" do
    Timecop.freeze(Time.current.change(sec: 0)) do
      code = ROTP::TOTP.new(credential.totp_secret).now
      post data_exports_path, params: { data_export: export.merge(code:) }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Private exported content")
      expect(response.body).not_to include(credential.totp_secret)
      post data_exports_path, params: { data_export: export.merge(code:) }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "consumes a recovery code once and shares the vault attempt limit" do
    code = credential.replace_recovery_codes!.first
    credential.save!
    post data_exports_path, params: { data_export: export.merge(code:) }
    expect(response).to have_http_status(:ok)
    post data_exports_path, params: { data_export: export.merge(code:) }
    expect(response).to have_http_status(:unprocessable_content)
    credential.reload.update!(attempts: 5, attempt_window_at: Time.current)
    post data_exports_path, params: { data_export: export.merge(code: ROTP::TOTP.new(credential.totp_secret).now) }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Too many attempts")
  end

  it "preserves ordinary exports without a factor and keeps protected values omitted" do
    post data_exports_path, params: { data_export: { scope: "account", format: "json" } }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Private exported content")
  end

  it "rejects another owner's profile before consuming a factor" do
    other_profile = create(:relationship_profile)
    post data_exports_path, params: { data_export: export.merge(scope: "relationship_profile", relationship_profile_id: other_profile.id, code: ROTP::TOTP.new(credential.totp_secret).now) }
    expect(response).to have_http_status(:not_found)
    expect(credential.reload.last_totp_at).to be_nil
  end

  it "explains the optional factor in both localized export forms" do
    %i[en es].each do |locale|
      I18n.with_locale(locale) { get data_control_path }
      document = Nokogiri::HTML(response.body)
      expect(document.css('input[name="data_export[code]"]').size).to eq(2)
      expect(document.css('input[name="data_export[code]"][required]')).to be_empty
      expect(response.body).to include(I18n.t("vault_mfa.export_help", locale:))
    end
  end
end
