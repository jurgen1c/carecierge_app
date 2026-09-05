require "rails_helper"

RSpec.describe "Admin operational overview", type: :system do
  it "offers scoped navigation with a usable layout across device sizes" do
    admin = create(:user, :admin)
    create(:approval_request)
    sign_in admin
    visit admin_root_path

    expect(page).to have_css("h1", text: "Admin overview")
    expect(page).to have_text("Waiting for owner review")
    expect(page).to have_text("Unavailable")
    expect(page).to have_link("Review feature flags", href: admin_feature_flags_path)
    expect(page).to have_link("Open admin ledger", href: admin_audit_events_path)
    [ [ 1440, 1000 ], [ 768, 1024 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      expect(page.evaluate_script("Array.from(document.querySelectorAll('main a')).every(link => link.getBoundingClientRect().height >= 44)")).to be(true)
      save_screenshot("admin-dashboard-#{width}.png", full: true) if ENV["CAPTURE_ADMIN_DASHBOARD_UI"] == "true"
    end
    click_link "Back to my dashboard"
    expect(page).to have_link("Admin overview", href: admin_root_path)
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
