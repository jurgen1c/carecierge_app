require "rails_helper"

RSpec.describe "Vendor shortlist comparison", type: :system do
  it "keeps comparison calm, review-only, actionable, and responsive" do
    shortlist = create(:vendor_shortlist, title: "Maya's birthday dinner")
    first = create(:vendor_option, vendor_shortlist: shortlist)
    second = create(
      :vendor_option,
      vendor_shortlist: shortlist,
      vendor: create(:vendor, user: shortlist.user, name: "Casa Verde", category: "restaurant"),
      notes: "Quiet private room."
    )
    sign_in shortlist.user

    visit vendor_shortlist_path(shortlist)

    expect(page).to have_css("h1", text: "Maya's birthday dinner")
    expect(page).to have_css("table[aria-label='Vendor comparison']")
    [ first.vendor.name, second.vendor.name, "Quiet private room." ].each do |text|
      expect(page).to have_content(text)
    end
    expect(page).to have_no_button("Book")
    expect(page).to have_no_button("Contact")

    verify_responsive_width(1440, 1000)
    save_screenshot("vendor-shortlists-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    comparison = find("table[aria-label='Vendor comparison']").find(:xpath, "..")
    expect(comparison.evaluate_script("this.scrollWidth > this.clientWidth")).to be(true)
    save_screenshot("vendor-shortlists-mobile.png", full: true) if capture_screenshots?

    first_details = find("summary", text: "Review #{first.vendor.name}").find(:xpath, "..")
    first_details.find("summary").click
    within(first_details) do
      favorite = find_button("Mark as favorite")
      expect(favorite.evaluate_script("this.getBoundingClientRect().height")).to be >= 44
      favorite.click
    end
    expect(first.reload).to be_favorite

    second_details = find("summary", text: "Review #{second.vendor.name}").find(:xpath, "..")
    second_details.find("summary").click
    within(second_details) { click_button "Select vendor" }
    expect(second.reload).to be_selected
    expect(page).to have_content("Selected vendor")

    shortlist.update!(title: "S" * VendorShortlist::MAX_TITLE_LENGTH)
    visit vendor_shortlist_path(shortlist)
    verify_responsive_width(390, 844)
    visit vendor_shortlists_path
    verify_responsive_width(390, 844)
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_VENDOR_SHORTLISTS_UI"] == "true"
  end
end
