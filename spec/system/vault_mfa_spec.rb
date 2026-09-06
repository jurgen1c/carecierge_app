require "rails_helper"

RSpec.describe "Vault MFA enrollment", type: :system do
  it "guides an owner through authenticator setup and once-only recovery acknowledgement" do
    user = create(:user, password: "known-password123")
    sign_in user
    visit vault_mfa_path
    expect(page).to have_content("does not change ordinary sign-in")
    capture_mfa("start")
    fill_in "Carecierge password", with: "known-password123"
    click_button "Start setup"
    expect(page).to have_content("Connect your authenticator")
    expect(page).to have_css("img[alt*='Authenticator setup QR']")
    capture_mfa("authenticator")
    fill_in "Authenticator code", with: ROTP::TOTP.new(user.reload.vault_mfa_credential.totp_secret).now
    click_button "Verify authenticator"
    expect(page).to have_content("Save your recovery codes")
    expect(page).to have_css("li code", count: 10)
    capture_mfa("recovery")
    check "I saved my recovery codes in a safe place."
    click_button "Enable vault MFA"
    expect(page).to have_content("Authenticator security is enabled")
    expect(user.reload).to be_vault_mfa_enabled
    expect(page).not_to have_css("li code")
    capture_mfa("enabled")
  end

  it "conceals an open vault in another tab before password recovery" do
    user = create(:user, password: "known-password123")
    profile = create(:relationship_profile, user:)
    memory = create(:memory_record, relationship_profile: profile, title: "Private plan", body: "Private open-tab content")
    PrivacyVault::Protect.call(actor: user, protectable: memory)
    sign_in user
    visit relationship_profile_privacy_vault_path(profile)
    fill_in "Password", with: "known-password123"
    click_button "Unlock for 10 minutes"
    expect(page).to have_content("Private open-tab content")
    vault_window = current_window
    within_window(open_new_window) do
      visit vault_mfa_path
      click_button "Sign out and set or reset my password"
      expect(page).to have_current_path(new_user_password_path)
    end
    within_window(vault_window) do
      expect(page).to have_content("Vault access ended")
      expect(page.html).not_to include("Private open-tab content")
    end
  end

  %i[authenticator recovery].each do |stage|
    it "conceals displayed #{stage} secrets when another tab signs out" do
      user = create(:user, password: "known-password123")
      sign_in user
      visit vault_mfa_path
      fill_in "Carecierge password", with: "known-password123"
      click_button "Start setup"
      expect(page).to have_content("Connect your authenticator")
      secret = user.reload.vault_mfa_credential.totp_secret
      if stage == :recovery
        fill_in "Authenticator code", with: ROTP::TOTP.new(secret).now
        click_button "Verify authenticator"
        expect(page).to have_css("li code", count: 10)
        secret = first("li code").text
      end
      secret_window = current_window
      within_window(open_new_window) do
        visit dashboard_path
        first("form[action='#{destroy_user_session_path}'] input[type=submit], form[action='#{destroy_user_session_path}'] button").click
        expect(page).to have_current_path(root_path)
      end
      within_window(secret_window) do
        expect(page).not_to have_content(secret)
        expect(page).not_to have_css("img[alt*='Authenticator setup QR']")
        expect(page).to have_content("Vault access ended")
      end
    end
  end

  %i[authenticator enrollment_recovery regenerated_recovery].each do |stage|
    it "expires unattended #{stage} secrets through the display timer" do
      user = create(:user, password: "known-password123")
      credential = create(:vault_mfa_credential, user:) if stage == :regenerated_recovery
      sign_in user
      visit vault_mfa_path
      if stage == :regenerated_recovery
        fill_in "regenerate_vault_mfa_password", with: "known-password123"
        fill_in "regenerate_vault_mfa_code", with: ROTP::TOTP.new(credential.totp_secret).now
        click_button "Replace recovery codes"
        expect(page).to have_css("li code", count: 10)
      else
        fill_in "Carecierge password", with: "known-password123"
        click_button "Start setup"
        expect(page).to have_content("Connect your authenticator")
        if stage == :enrollment_recovery
          fill_in "Authenticator code", with: ROTP::TOTP.new(user.reload.vault_mfa_credential.totp_secret).now
          click_button "Verify authenticator"
          expect(page).to have_css("li code", count: 10)
        end
      end
      secret = first("code").text
      duration = page.evaluate_script("document.body.dataset.privacyVaultLeaseDurationValue")
      expect(duration.to_i).to be_between(1, 10.minutes.in_milliseconds)
      page.execute_script("document.body.setAttribute('data-privacy-vault-lease-duration-value', 50)")
      expect(page).to have_content("Vault access ended")
      expect(page.html).not_to include(secret)
      expect(page).not_to have_css("img[alt*='Authenticator setup QR']")
    end
  end

  def capture_mfa(state)
    return unless ENV["CAR82_SCREENSHOTS"]

    [ [ 390, 844 ], [ 768, 1024 ], [ 1440, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      page.save_screenshot(File.join(ENV.fetch("CAR82_SCREENSHOTS"), "mfa-#{state}-#{width}.png"), full: true)
    end
  end
end
