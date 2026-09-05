require "rails_helper"

RSpec.describe "Shared planning", type: :system do
  it "supports a responsive, explicit shared-item workflow" do
    space = create(:shared_relationship_space)
    create(:shared_item, shared_relationship_space: space, title: "Dinner by the garden")
    sign_in space.owner
    page.current_window.resize_to(390, 844)
    visit dashboard_path
    find("summary", text: I18n.t("daily_feed.navigation.menu")).click
    click_link "Shared couple spaces"
    click_link space.title
    expect(page).to have_content("Your private notes stay private")
    [ [ 1440, 1000 ], [ 768, 1024 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      if ENV["CAPTURE_SHARED_SPACES_UI"] == "true"
        page.save_screenshot("/tmp/codex-jira-batches/carecierge-20260905-CAR-78-CAR-79-CAR-80-CAR-81/CAR-78/shared-space-#{width}.png", full: true)
      end
    end
    click_link "Add shared item"
    select "Task", from: "Type"
    fill_in "Title", with: "Choose the restaurant"
    select "Both can edit", from: "Who can edit and complete this?"
    click_button "Save shared item"
    expect(page).to have_content("Choose the restaurant")
    click_button "I’ll take this"
    expect(page).to have_content("Taking care of this:")
    find("summary", text: "Manage sharing").click
    expect(page).to have_unchecked_field("I understand this deletes the entire shared space for both people.")
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
