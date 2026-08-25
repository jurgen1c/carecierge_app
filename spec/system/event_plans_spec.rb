require "rails_helper"

RSpec.describe "Event plan workspace", type: :system do
  it "reveals anniversary effort and relationship-specific prior context during manual creation" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    other_profile = create(:relationship_profile, user:, preferred_name: "Jordan")
    prior_plan = create(
      :event_plan,
      user:,
      relationship_profile: profile,
      title: "Last year's quiet dinner",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create(
      :event_plan,
      user:,
      relationship_profile: other_profile,
      title: "Jordan's prior anniversary",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    sign_in user

    visit new_event_plan_path
    select profile.display_name, from: "Relationship"
    select "Anniversary", from: "Occasion"

    expect(page).to have_select("Effort level", visible: true)
    expect(page).to have_select(
      "Prior anniversary context",
      options: [ "Do not use a prior plan", prior_plan.title ],
      visible: true
    )
    expect(page).not_to have_select("Prior anniversary context", with_options: [ "Jordan's prior anniversary" ])

    page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")
    expect(page).to have_select(
      "Prior anniversary context",
      with_options: [ prior_plan.title, "Jordan's prior anniversary" ],
      visible: true
    )

    select prior_plan.title, from: "Prior anniversary context"
    select "Birthday", from: "Occasion"

    expect(page).not_to have_select("Prior anniversary context", visible: true)
    expect(page.evaluate_script("document.getElementById('prior_event_plan_id').disabled")).to be(true)
    expect(page.evaluate_script("document.getElementById('prior_event_plan_id').value")).to eq("")
  end

  it "loads prior anniversary choices for every relationship when a manual form is preselected" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    other_profile = create(:relationship_profile, user:, preferred_name: "Jordan")
    other_prior_plan = create(
      :event_plan,
      user:,
      relationship_profile: other_profile,
      title: "Jordan's prior anniversary",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    sign_in user

    visit new_event_plan_path(relationship_profile_id: profile.id)
    select other_profile.display_name, from: "Relationship"
    select "Anniversary", from: "Occasion"

    expect(page).to have_select(
      "Prior anniversary context",
      options: [ "Do not use a prior plan", other_prior_plan.title ],
      visible: true
    )
  end

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
