require "rails_helper"

RSpec.describe "Event plan workspace", type: :system do
  it "keeps planning relationship-aware, review-only, actionable, and responsive" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    plan = create(:event_plan, user:, relationship_profile: profile, title: "Maya's birthday dinner")
    decision = create(:plan_task, event_plan: plan, kind: "decision", title: "Choose the dinner format")
    create(:plan_task, event_plan: plan, kind: "message_draft", title: "Draft the invitation")
    sign_in user

    visit event_plan_path(plan)

    expect(page).to have_css("h1", text: "Maya's birthday dinner")
    expect(page).to have_content("Choose the dinner format")
    expect(page).to have_content("Draft only — nothing is sent")
    expect(page).to have_content("Suggestions are added for your review")
    expect(page).to have_content("Birthday concierge")
    expect(page).to have_content("Your next step")
    expect(page).to have_content("You review every draft and decide what happens next")
    expect(page).to have_link("Open this step", href: event_plan_path(plan, anchor: "plan-task-#{decision.id}"))
    expect(page).to have_css("button[aria-label='Complete Choose the dinner format']")
    expect(page).to have_no_link("Buy now")

    verify_responsive_width(1440, 1000)
    save_screenshot("event-plans-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(768, 1024)
    save_screenshot("event-plans-tablet.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    save_screenshot("event-plans-mobile.png", full: true) if capture_screenshots?

    find("button[aria-label='Complete Choose the dinner format']").click
    expect(decision.reload).to be_completed
    expect(page).to have_content("1 of 2 steps completed")
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_EVENT_PLANS_UI"] == "true"
  end
end
