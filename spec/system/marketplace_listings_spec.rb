require "rails_helper"

RSpec.describe "Marketplace browsing", type: :system do
  it "supports browsing, comparison and private saving at phone, tablet, and desktop widths" do
    user = create(:user)
    create(:event_plan, user:)
    listing = create(:marketplace_listing)
    sign_in user
    visit marketplace_listings_path
    expect(page).to have_content("Carecierge curation")
    [ [ 390, 844 ], [ 768, 1024 ], [ 1440, 1000 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      save_screenshot("marketplace-#{width}.png", full: true) if ENV["CAPTURE_MARKETPLACE_UI"] == "true"
    end
    check "Compare #{listing.name}"
    click_button "Compare marketplace options"
    expect(page).to have_css("h1", text: "Compare marketplace options")
    click_link listing.name
    click_button "Save to my vendors"
    expect(page).to have_content("Use this saved choice")
    expect(user.vendors.count).to eq(1)
    page.current_window.resize_to(390, 844)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
    save_screenshot("marketplace-saved-mobile.png", full: true) if ENV["CAPTURE_MARKETPLACE_UI"] == "true"
  ensure
    page.current_window.resize_to(1280, 800)
  end

  it "shows the saved gift after submitting the marketplace draft with Turbo" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    listing = create(:marketplace_listing)
    MarketplaceListings::Save.call(user:, listing:)
    sign_in user
    visit marketplace_listing_path(listing)
    select profile.display_name, from: "gift_relationship"
    click_button "Gift idea"
    expect(page).to have_field("gift_vendor", with: listing.name)
    fill_in "gift_occasion", with: "Birthday"
    click_button I18n.t("gifts.form.create")
    expect(page).to have_css("#gifts_section", text: listing.name)
    expect(page).to have_no_field("gift_name", with: listing.name)
    expect(profile.gifts.count).to eq(1)
  end

  it "works without JavaScript" do
    driven_by :rack_test
    user = create(:user)
    listing = create(:marketplace_listing)
    sign_in user
    visit marketplace_listings_path
    click_button "Compare marketplace options"
    expect(page).to have_content("Choose one to five options to compare.")
    fill_in "Search names or curated descriptions", with: "Bloom"
    click_button "Search marketplace"
    click_link listing.name
    click_button "Save to my vendors"
    expect(page).to have_content("Use this saved choice")
    click_link "Shortlist", exact: true
    expect(page).to have_checked_field(user.vendors.sole.name)
  end
end
