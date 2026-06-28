require "rails_helper"

RSpec.describe "Relationship profile Lexxy editor", type: :system do
  it "lets a signed-in user create rich profile notes" do
    user = create(:user)
    sign_in user

    visit new_relationship_profile_path

    expect(page).to have_css("lexxy-editor#relationship_profile_notes[connected]")
    expect(page).to have_css("lexxy-editor#relationship_profile_private_notes[connected]")

    fill_in "First name", with: "Maya"
    fill_in "Last name", with: "Rivera"
    fill_in "Relationship type", with: "Friend"
    set_lexxy_value("relationship_profile_notes", "<p>Bring <strong>tea</strong> to garden walks.</p>")
    set_lexxy_value("relationship_profile_private_notes", "<p>Prefers low-key check-ins.</p>")

    click_button "Save profile"

    expect(page).to have_current_path(relationship_profile_path(RelationshipProfile.last))
    expect(page).to have_content("Bring tea to garden walks.")
    expect(page).to have_content("Prefers low-key check-ins.")

    profile = user.relationship_profiles.find_by!(first_name: "Maya")
    expect(profile.notes.to_plain_text).to include("Bring tea to garden walks.")
    expect(profile.private_notes.to_plain_text).to include("Prefers low-key check-ins.")
  end

  private

  def set_lexxy_value(id, html)
    page.execute_script(<<~JS, id, html)
      const editor = document.getElementById(arguments[0]);
      editor.value = arguments[1];
    JS
  end
end
