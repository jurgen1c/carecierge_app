require "rails_helper"

RSpec.describe "Vendor onboarding and moderation", type: :request do
  let(:user) { create(:user) }
  let(:moderator) { create(:user, admin: true) }

  it "preserves vendor exports alongside fresh vault MFA verification" do
    password = "known-password123"
    user.update!(password:, password_confirmation: password)
    credential = create(:vault_mfa_credential, user:)
    account = create(:vendor_account, user:)
    VendorAccounts::Transition.call(user:, account:, to: "submitted", version: "0")
    profile = create(:relationship_profile, user:)
    memory = create(:memory_record, relationship_profile: profile, body: "Protected owner memory")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    sign_in user

    export = { scope: "account", format: "json" }
    post data_exports_path, params: { data_export: export }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("vendor_account", "business_name")).to eq(account.business_name)
    expect(response.body).not_to include("Protected owner memory", credential.totp_secret)

    export = export.merge(include_sensitive: "1", current_password: password)
    post data_exports_path, params: { data_export: export }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include("Protected owner memory")

    Timecop.freeze(Time.current.change(sec: 0)) do
      code = ROTP::TOTP.new(credential.totp_secret).now
      post data_exports_path, params: { data_export: export.merge(code:) }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Protected owner memory")
      expect(response.body).not_to include(credential.totp_secret)
      business = response.parsed_body.fetch("vendor_account")
      expect(business["business_name"]).to eq(account.business_name)
      expect(business.fetch("reviews").sole).not_to have_key("actor_id")
      post data_exports_path, params: { data_export: export.merge(code:) }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "requires login and a confirmed identity" do
    get vendor_account_path
    expect(response).to redirect_to(new_user_session_path)
    unconfirmed = create(:user, confirmed_at: nil)
    sign_in unconfirmed
    post vendor_account_path
    expect(response).not_to have_http_status(:success)
    expect(VendorAccount.count).to eq(0)
  end

  it "starts one draft, resumes, saves bounded data, and submits valid content" do
    sign_in user
    get vendor_account_path
    expect(response.body).to include("Start my business profile")
    2.times { post vendor_account_path }
    account = user.reload.vendor_account
    expect(VendorAccount.where(user:).count).to eq(1)
    get vendor_account_path
    expect(response.body).to include('name="vendor_account[lock_version]"')
    post submit_vendor_account_path, params: { version: account.lock_version.to_s }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('role="alert"', 'href="#vendor_account_business_name"')
    patch vendor_account_path, params: { vendor_account: attributes_for(:vendor_account).merge(lock_version: "0", status: "approved", user_id: moderator.id) }
    expect(response).to redirect_to(vendor_account_path)
    expect(account.reload).to have_attributes(status: "draft", user:)
    post submit_vendor_account_path, params: { version: account.lock_version.to_s }
    follow_redirect!
    expect(response.body).to include("Submitted · awaiting review")
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "does not expose another vendor or consumer records through vendor routes" do
    own = create(:vendor_account, user:)
    other = create(:vendor_account, business_name: "Other private draft")
    profile = create(:relationship_profile, user: other.user, first_name: "Private", last_name: "Consumer")
    sign_in user
    get vendor_account_path, params: { id: other.id, relationship_profile_id: profile.id }
    expect(response.body).not_to include(other.business_name, profile.display_name)
    patch vendor_account_path, params: { id: other.id, vendor_account: { business_name: "Own revised name", lock_version: "0", user_id: other.user_id } }
    expect(own.reload.business_name).to eq("Own revised name")
    expect(other.reload.business_name).to eq("Other private draft")
    get admin_vendor_account_path(other)
    expect(response).to have_http_status(:forbidden)
    patch admin_vendor_account_path(other), params: { moderation: { decision: "approved", version: "0" } }
    expect(response).to have_http_status(:forbidden)
    get relationship_profile_path(profile)
    expect(response).to have_http_status(:not_found)
  end

  it "gates consumer index, detail, comparison, and saving through moderation" do
    account = create(:vendor_account, user:)
    sign_in user
    post submit_vendor_account_path, params: { version: "0" }
    get marketplace_listings_path
    expect(response.body).not_to include("Orchid Studio")
    sign_in moderator
    get admin_vendor_accounts_path
    expect(response.body).to include("Orchid Studio")
    patch admin_vendor_account_path(account), params: { moderation: { decision: "rejected", version: account.reload.lock_version.to_s } }
    expect(response).to have_http_status(:unprocessable_content)
    patch admin_vendor_account_path(account), params: { moderation: { decision: "approved", version: account.reload.lock_version.to_s } }
    expect(response).to redirect_to(admin_vendor_account_path(account))
    listing = account.reload.marketplace_listing
    get marketplace_listing_path(listing)
    expect(response.body).to include("Vendor-supplied offerings")
    expect(response.body).not_to include("Carecierge curation")
    patch admin_vendor_account_path(account), params: { moderation: { decision: "suspended", reason: "Review required", version: account.lock_version.to_s } }
    get marketplace_listings_path
    expect(response.body).not_to include("Orchid Studio")
    get marketplace_listing_path(listing)
    expect(response).to have_http_status(:not_found)
    get compare_marketplace_listings_path, params: { listing_ids: [ listing.id ] }
    expect(response).to have_http_status(:not_found)
    post save_marketplace_listing_path(listing)
    expect(response).to have_http_status(:not_found)
  end

  it "recovers from invalid values and missing or stale revisions" do
    account = create(:vendor_account, user:)
    sign_in user
    patch vendor_account_path, params: { vendor_account: { business_name: "x" * 201, lock_version: "0" } }
    expect(response).to have_http_status(:unprocessable_content)
    patch vendor_account_path, params: { vendor_account: { business_name: "Overwrite" } }
    expect(response).to redirect_to(vendor_account_path)
    expect(account.reload.business_name).to eq("Orchid Studio")
    sign_in moderator
    patch admin_vendor_account_path(account), params: { moderation: { decision: "approved" } }
    expect(response).to redirect_to(admin_vendor_account_path(account))
    get admin_vendor_account_path(SecureRandom.uuid)
    expect(response).to have_http_status(:not_found)
  end

  it "retains published status and invalid input after an approved edit fails" do
    account = create(:vendor_account, user:, status: "submitted")
    VendorAccounts::Transition.call(user: moderator, account:, to: "approved", version: "0")
    sign_in user
    patch vendor_account_path, params: { vendor_account: { categories: Vendor::CATEGORIES.first(6), lock_version: account.lock_version.to_s } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(account.reload.status).to eq("approved")
    expect(account.marketplace_listing).to be_published
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("#profile-status").text).to eq("Approved · visible in the marketplace")
    expect(document.css('input[name="vendor_account[categories][]"][checked]').size).to eq(6)
    expect(document.at_css("#categories-errors").text).to be_present
  end

  it "keeps history pagination on a GET route after invalid submission" do
    account = create(:vendor_account, user:, offerings: "")
    21.times { account.record_transition!(from: "draft", actor: user) }
    sign_in user
    post submit_vendor_account_path, params: { version: "0" }
    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    next_link = document.css("nav a").find { |link| link["href"].include?("page=2") }
    expect(next_link["href"]).to eq(vendor_account_path(page: 2))
    get next_link["href"]
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).css("#review-history + ol > li").size).to eq(1)
  end

  it "renders Spanish forms and errors with English remaining the default" do
    expect(I18n.default_locale).to eq(:en)
    expect(I18n.available_locales).to include(:en, :es)
    create(:vendor_account, user:, offerings: "")
    sign_in user
    I18n.with_locale(:es) do
      get vendor_account_path
      expect(response.body).to include("Mi negocio en el mercado", "Guardar borrador del negocio")
      post submit_vendor_account_path, params: { version: "0" }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("translation missing")
      expect(response.body).to include("Revisa los siguientes detalles")
    end
  end
end
