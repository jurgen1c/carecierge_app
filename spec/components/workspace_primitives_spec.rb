require "rails_helper"

RSpec.describe "Workspace primitives", type: :component do
  it "keeps untrusted person names as text and hides decorative initials" do
    render_inline(PersonIdentityComponent.new(name: "María <script>alert(1)</script>", subtitle: "Friend"))

    expect(page).to have_text("María <script>alert(1)</script>")
    expect(page).to have_no_css("script")
    expect(page).to have_css(".person-avatar[aria-hidden='true']")
  end

  it "provides a complete localized date to assistive technology" do
    date = Date.new(2026, 9, 12)
    I18n.with_locale(:es) { render_inline(DateMarkerComponent.new(date:)) }

    expect(page).to have_css("time[datetime='2026-09-12'][aria-label='12 de septiembre de 2026']")
  end

  it "opens a form disclosure when validation needs attention" do
    render_inline(FormRevealComponent.new(label: "Add a detail", expanded: true)) { '<p role="alert">Check the date</p>'.html_safe }

    expect(page).to have_css("details[open] > summary", text: "Add a detail")
    expect(page).to have_css("[role='alert']", text: "Check the date")
  end

  it "retains addressable profile sections with factual context" do
    render_inline(ProfileSectionComponent.new(section: "plans", context: "Call Maya tomorrow", expanded: false)) { "Open work" }

    expect(page).to have_css("#profile-plans > summary", text: "Call Maya tomorrow")
    expect(page).to have_no_css("details[open]")
  end
end
