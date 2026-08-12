require "rails_helper"

RSpec.describe "Message drafting workspace", type: :system do
  it "keeps drafting editable, review-only, and responsive" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, key: "Message style", value: "Short and sincere")
    create(:relationship_note, relationship_profile: profile, private: true, body: "Use a gentle opening.")
    draft = create(:message_draft, user:, relationship_profile: profile, draft_type: "check_in", tone: "warm")
    create(:draft_revision, message_draft: draft, position: 1, content: "I hope your week has felt gentle.")
    create(:draft_revision, message_draft: draft, position: 2, origin: "edited", content: "Thinking of you. How has your week felt?")
    sign_in user

    visit relationship_profile_path(profile, anchor: "message-drafting")

    expect(page).to have_css("#message-drafting")
    expect(page).to have_content("Draft only — nothing will be sent")
    expect(page).to have_field("Draft", with: "Thinking of you. How has your week felt?")
    expect(page).to have_unchecked_field("Use private notes for this draft")
    expect(page).to have_button("Restore", count: 2)
    expect(page).to have_no_button("Send")

    capture_workspace_screenshots if ENV["CAPTURE_MESSAGE_DRAFTS_UI"] == "true"
  end

  private

  def capture_workspace_screenshots
    page.current_window.resize_to(1440, 1100)
    expect(page.evaluate_script("window.innerWidth")).to be >= 1024
    save_screenshot("message-drafts-desktop-viewport.png", full: false)
    save_screenshot("message-drafts-desktop.png", full: true)
    page.current_window.resize_to(390, 844)
    expect(page.evaluate_script("window.innerWidth")).to be < 1024
    save_screenshot("message-drafts-mobile-viewport.png", full: false)
    save_screenshot("message-drafts-mobile.png", full: true)
    page.current_window.resize_to(1280, 800)
  end
end
