require "rails_helper"

RSpec.describe "Relationship memory search", type: :system do
  it "lets a signed-in user filter memory and open the matching source" do
    user = create(:user)
    profile = create(:relationship_profile, user:, first_name: "Ana", last_name: "Torres")
    create(:relationship_preference, relationship_profile: profile, key: "Weekend plans", value: "Hiking")
    create(:gift, relationship_profile: profile, name: "Hiking daypack")
    sign_in user

    visit relationship_search_path

    fill_in "Search words", with: "hiking"
    select "Preference", from: "Source"
    click_button "Search memory"

    expect(page).to have_content("1 result across 1 relationship")
    expect(page).to have_content("Ana Torres")
    expect(page).to have_content("Weekend plans")
    expect(page).to have_content("Hiking")
    expect(page).not_to have_content("Hiking daypack")
    page.current_window.resize_to(390, 844)

    expect(page).to have_field("Search words", with: "hiking")
    expect(page).to have_css("a[aria-label='Open Weekend plans']")
  end
end
