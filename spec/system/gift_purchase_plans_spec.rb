require "rails_helper"

RSpec.describe "Gift purchase assistance", type: :system do
  it "saves manual logistics and prepares a reminder with accessible responsive controls" do
    gift = create(:gift, name: "A thoughtful book")
    sign_in gift.relationship_profile.user
    visit relationship_profile_gift_purchase_plan_path(gift.relationship_profile, gift)
    fill_in "Budget", with: "30.25"
    within_fieldset "Option 1" do
      fill_in "Vendor or purchase option", with: "Local books"
      fill_in "Estimated total cost", with: "24.95"
      fill_in "Purchase link", with: "https://books.example/gift"
      check "I checked this option"
    end
    fill_in "Private shipping notes", with: "Leave with the owner"
    select "Purchased by me", from: "Purchase status"
    click_button "Save purchase plan"
    expect(page).to have_content("Purchase plan saved.")
    expect(page).to have_content("Suggested option")
    expect(gift.reload.purchase_plan.purchase_status).to eq("purchased")
    [ [ 1440, 1000 ], [ 768, 1024 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      if ENV["CAPTURE_GIFT_PURCHASE_UI"] == "true"
        save_screenshot("gift-purchase-#{width}.png", full: true)
      end
    end
    click_link "Prepare follow-up reminder"
    expect(page).to have_field("Reminder", with: "Follow up on gift: A thoughtful book")
    expect(Reminder.count).to eq(0)
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
