require "rails_helper"

RSpec.describe "User access flow", type: :system do
  it "lets a visitor register and recover from validation errors" do
    visit new_user_registration_path

    fill_in "Email", with: "new-user@example.com"
    fill_in "Password", with: "short"
    fill_in "Confirm password", with: "different"
    click_button "Create account"

    expect(page).to have_content("We could not create your account")
    expect(page).to have_content("Confirm password does not match")

    fill_in "Email", with: "new-user@example.com"
    fill_in "Password", with: "password123"
    fill_in "Confirm password", with: "password123"
    click_button "Create account"

    expect(page).to have_content("Check your email to confirm your account")
    expect(User.find_by(email: "new-user@example.com")).to be_present
  end

  it "lets a confirmed user log in and log out" do
    create(:user, email: "user@example.com", password: "password123")

    visit new_user_session_path

    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "wrong-password"
    click_button "Sign in"

    expect(page).to have_content("Email or password is invalid")

    fill_in "Email", with: "user@example.com"
    fill_in "Password", with: "password123"
    click_button "Sign in"

    expect(page).to have_content("Tell us who to remember first")
    expect(page).to have_current_path(onboarding_path)

    click_button "Skip for now"

    expect(page).to have_current_path(dashboard_path)

    click_button "Sign out"

    expect(page).to have_current_path(root_path)
    expect(page).to have_link("Sign in")
  end

  it "keeps supported recovery and OAuth entry points reachable from sign in" do
    visit new_user_session_path

    expect(page).to have_link("Forgot your password?", href: new_user_password_path)
    expect(page).to have_link("Resend confirmation instructions", href: new_user_confirmation_path)
    expect(page).to have_link("Resend unlock instructions", href: new_user_unlock_path)
    expect(page).to have_button("Continue with Google")
  end
end
