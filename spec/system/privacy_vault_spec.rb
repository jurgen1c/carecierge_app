require "rails_helper"

RSpec.describe "Privacy vault", type: :system do
  it "requires a password before revealing and protecting relationship context" do
    user = create(:user, password: "password123", password_confirmation: "password123")
    profile = create(:relationship_profile, user:, first_name: "Maya")
    create(
      :memory_record,
      relationship_profile: profile,
      title: "Private anniversary plan",
      body: "Book the quiet table."
    )
    sign_in user

    visit relationship_profile_path(profile)

    expect(page).to have_content("Privacy vault")
    expect(page).to have_content("Book the quiet table.")
    expect(page).to have_link("Open vault", href: relationship_profile_privacy_vault_path(profile))
    visit relationship_profile_privacy_vault_path(profile)

    expect(page).to have_field("Password")
    expect(page).not_to have_content("Private anniversary plan")
    capture_vault_screenshot("privacy-vault-locked") if capture_vault_ui?

    fill_in "Password", with: "password123"
    click_button "Unlock for 10 minutes"

    expect(page).to have_content("Unlocked for 10 minutes")
    expect(page).to have_content("Private anniversary plan")
    within("section.rounded-xl", text: "Private anniversary plan") { click_button "Protect" }

    expect(page).to have_content("Item protected in the privacy vault.")
    expect(page).to have_content("Book the quiet table.")
    expect(page).to have_content("Excluded from suggestions")
    capture_vault_screenshot("privacy-vault-unlocked") if capture_vault_ui?

    click_button "Lock vault"

    expect(page).to have_field("Password")
    expect(page).not_to have_content("Book the quiet table.")
  end

  it "removes decrypted content from the DOM when the client lease expires" do
    user = create(:user, password: "password123", password_confirmation: "password123")
    profile = create(:relationship_profile, user:, first_name: "Maya")
    memory = create(:memory_record, relationship_profile: profile, title: "Private plan", body: "Secret in the DOM")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    sign_in user
    visit relationship_profile_privacy_vault_path(profile)
    fill_in "Password", with: "password123"
    click_button "Unlock for 10 minutes"

    expect(page).to have_content("Secret in the DOM")
    page.execute_script <<~JAVASCRIPT
      document.querySelector('[data-controller="privacy-vault"]')
        .setAttribute('data-privacy-vault-lease-duration-value', 50)
    JAVASCRIPT

    expect(page).to have_content("Vault access ended")
    expect(page.html).not_to include("Secret in the DOM")
  end

  it "removes decrypted content when another tab signals an explicit lock" do
    user = create(:user, password: "password123", password_confirmation: "password123")
    profile = create(:relationship_profile, user:, first_name: "Maya")
    memory = create(:memory_record, relationship_profile: profile, title: "Private plan", body: "Cross-tab secret")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    sign_in user
    visit relationship_profile_privacy_vault_path(profile)
    fill_in "Password", with: "password123"
    click_button "Unlock for 10 minutes"

    expect(page).to have_content("Cross-tab secret")
    page.execute_script <<~JAVASCRIPT
      const vault = document.querySelector('[data-controller="privacy-vault"]')
      window.dispatchEvent(new StorageEvent('storage', { key: vault.dataset.privacyVaultLockKeyValue }))
    JAVASCRIPT

    expect(page).to have_content("Vault access ended")
    expect(page.html).not_to include("Cross-tab secret")
  end

  private

  def capture_vault_ui?
    ENV["CAPTURE_PRIVACY_VAULT_UI"] == "true"
  end

  def capture_vault_screenshot(name)
    page.current_window.resize_to(1440, 1000)
    save_screenshot("#{name}-desktop.png", full: true)
    page.current_window.resize_to(390, 844)
    save_screenshot("#{name}-mobile.png", full: true)
    page.current_window.resize_to(1280, 800)
  end
end
