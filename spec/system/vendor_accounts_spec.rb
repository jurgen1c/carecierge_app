require "rails_helper"

RSpec.describe "Business profile onboarding", type: :system do
  %i[en es].each do |locale|
    it "supports saving, errors, submission and review history without JavaScript in #{locale}" do
      driven_by :rack_test
      I18n.with_locale(locale) do
        user = create(:user)
        sign_in user
        visit vendor_account_path
        click_button I18n.t("vendor_accounts.begin")
        click_button I18n.t("vendor_accounts.submit")
        expect(page).to have_css('[role="alert"]')
        attributes_for(:vendor_account).except(:categories).each do |field, value|
          fill_in I18n.t("vendor_accounts.fields.#{field}"), with: value
        end
        check I18n.t("vendors.categories.florist")
        click_button I18n.t("vendor_accounts.save")
        visit vendor_account_path
        expect(page).to have_field(I18n.t("vendor_accounts.fields.business_name"), with: "Orchid Studio")
        click_button I18n.t("vendor_accounts.submit")
        expect(page).to have_content(I18n.t("vendor_accounts.states.submitted"))
        expect(user.reload.vendor_account.status).to eq("submitted")
      end
    end
  end

  it "supports keyboard focus and readable phone, tablet and desktop forms" do
    user = create(:user)
    create(:vendor_account, user:)
    sign_in user
    visit vendor_account_path
    input = find("#vendor_account_business_name")
    input.click
    input.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.id")).to eq("vendor_account_service_area")
    expect(page.evaluate_script("getComputedStyle(document.activeElement).outlineStyle")).not_to eq("none")
    [ [ 390, 844 ], [ 768, 1024 ], [ 1440, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      save_screenshot("vendor-account-#{width}.png", full: true) if ENV["CAPTURE_VENDOR_UI"] == "true"
    end
    click_button "Submit saved profile for review"
    expect(page).to have_content("Submitted · awaiting review")
    save_screenshot("vendor-account-submitted.png", full: true) if ENV["CAPTURE_VENDOR_UI"] == "true"
  ensure
    page.current_window.resize_to(1280, 800)
  end

  it "supports moderation, rejection recovery and approval without JavaScript" do
    driven_by :rack_test
    account = create(:vendor_account, status: "submitted")
    sign_in create(:user, admin: true)
    visit admin_vendor_accounts_path
    click_link account.business_name
    select "Reject with a reason", from: "Decision"
    click_button "Record review decision"
    expect(page).to have_css('[role="alert"]')
    expect(page).to have_select("Decision", selected: "Reject with a reason")
    fill_in "Reason for the vendor", with: "Please confirm business coverage"
    click_button "Record review decision"
    expect(page).to have_content("Rejected · changes needed")
    expect(page).to have_content("Please confirm business coverage")
  end
end
