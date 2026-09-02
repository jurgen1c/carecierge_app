require "rails_helper"

RSpec.describe "Approval queue", type: :system do
  it "supports a source-to-consequence-to-decision review at desktop and mobile widths" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Elena")
    recap = create(:conversation_recap, relationship_profile: profile, title: "Dinner conversation")
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: recap,
      title: "Enjoys live jazz",
      body: "Enjoys live jazz for special evenings.",
      source_excerpt: "We talked about the trio playing downtown.",
      confidence: "medium"
    )
    create(:memory_record, relationship_profile: profile, title: "Prefers quiet tables", source: "ai_inferred", confidence: "low")
    sign_in user

    visit approvals_path

    expect(page).to have_css("h1", text: "Approval queue")
    expect(page).to have_css("h3", text: "Understand the source")
    expect(page).to have_css("h3", text: "Review the consequence")
    expect(page).to have_css("h3", text: "Decide")
    click_link "Enjoys live jazz"
    expect(page).to have_content("Dinner conversation")
    expect(page).to have_content("No message will be sent")
    expect(page).to have_button("Approve")
    expect(page).to have_link("Edit")
    expect(page).to have_button("Reject")
    expect(page).to have_link("Keep for later")
    expect(page).to have_button("Dismiss")

    verify_responsive_width(1440, 1000)
    save_screenshot("approval-queue-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    save_screenshot("approval-queue-mobile.png", full: true) if capture_screenshots?

    click_link "Edit"
    fill_in "Corrected memory title", with: "Enjoys intimate live jazz"
    click_button "Save and approve"

    expect(page).to have_content("Changes saved and approval recorded.")
    expect(proposal.reload).to have_attributes(status: "corrected", corrected_title: "Enjoys intimate live jazz")
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_APPROVAL_QUEUE_UI"] == "true"
  end
end
