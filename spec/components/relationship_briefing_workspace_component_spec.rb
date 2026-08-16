require "rails_helper"

RSpec.describe RelationshipBriefingWorkspaceComponent, type: :component do
  it "renders the confirmed scan-first briefing with provenance and review-only actions" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    briefing = create(:relationship_briefing, user: profile.user, relationship_profile: profile)

    render_inline described_class.new(
      relationship_profile: profile,
      briefing:,
      private_notes_available: true,
      vault_items_available: true,
      vault_unlocked: false
    )

    expect(page).to have_css("#relationship-briefing")
    expect(page).to have_field("What are you preparing for?", with: briefing.interaction_context)
    expect(page).to have_content("She started a new role.")
    expect(page).to have_content("Confirmed")
    expect(page).to have_content("Timeline entry from May 22")
    expect(page).to have_button("Save for later")
    expect(page).to have_button("Dismiss")
    expect(page).to have_link("Create reminder")
    expect(page).to have_link("Open message draft")
    expect(page).to have_link("Unlock the privacy vault")
    expect(page).to have_unchecked_field("Include private notes for this briefing")
    expect(page).to have_unchecked_field("Include vault items for this briefing", disabled: true)
    expect(rendered_content).to include("bg-primary", "border-private-line")
    expect(rendered_content).not_to match(/(?:emerald|red)-\d/)
  end

  it "renders a localized empty state in Spanish" do
    profile = create(:relationship_profile)

    I18n.with_locale(:es) do
      render_inline described_class.new(relationship_profile: profile)
    end

    expect(page).to have_content("Prepárate para el próximo momento")
    expect(page).to have_button("Crear informe")
    expect(page).to have_no_content("Translation missing")
  end
end
