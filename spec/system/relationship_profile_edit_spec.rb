require "rails_helper"

RSpec.describe "Relationship profile editing", type: :system do
  it "lets a signed-in user remove nested relationship details" do
    user = create(:user)
    profile = create(:relationship_profile, user:, first_name: "Maya", last_name: "Rivera")
    create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com")
    create(:relationship_note, relationship_profile: profile, body: "Remember tea.")
    create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "decaf")
    create(:relationship_tag, relationship_profile: profile, name: "garden")
    sign_in user

    visit edit_relationship_profile_path(profile)

    check "Remove this contact method"
    check "Remove this note"
    check "Remove this preference"
    check "Remove this tag"
    click_button "Save profile"

    expect(page).to have_current_path(relationship_profile_path(profile))
    expect(page).to have_content("Relationship profile was updated.")

    profile.reload
    expect(profile.contact_methods).to be_empty
    expect(profile.relationship_notes).to be_empty
    expect(profile.relationship_preferences).to be_empty
    expect(profile.relationship_tags).to be_empty
  end
end
