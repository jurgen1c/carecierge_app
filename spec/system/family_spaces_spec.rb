require "rails_helper"

RSpec.describe "Family planning", type: :system do
  it "supports calendar, responsibility and RSVP flows across responsive layouts" do
    space = create(:shared_relationship_space, mode: "family", partner: nil, invited_email: nil, accepted_at: nil)
    create(:shared_item, shared_relationship_space: space, title: "Lunch with the family", category: "rsvp", kind: "plan", due_at: Time.utc(2027, 12, 24, 18))
    sign_in space.owner
    visit shared_relationship_space_path(space)
    expect(page).to have_content("Your private notes stay private")
    [ [ 1440, 1000 ], [ 768, 1024 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      page.save_screenshot("#{ENV['FAMILY_SCREENSHOT_DIR']}/family-#{width}.png", full: true) if ENV["FAMILY_SCREENSHOT_DIR"]
    end
    select "Attending", from: "My response"
    click_button "Save my response"
    expect(page).to have_content("Attending")
    click_link "Add shared item"
    select "Task", from: "Type"
    select "Care tasks", from: "Family activity"
    fill_in "Title", with: "Bring groceries"
    click_button "Save shared item"
    expect(page).to have_content("Bring groceries")
    click_button "I’ll take this"
    select "My responsibilities", from: "Show"
    click_button "Show items"
    expect(page).to have_content("Bring groceries")
    expect(page).not_to have_content("Lunch with the family")
    expect(page).to have_css('meta[name="turbo-cache-control"][content="no-cache"]', visible: false)
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
