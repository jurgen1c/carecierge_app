require "rails_helper"

RSpec.describe PersonaTraitComponent, type: :component do
  let(:routes) { Rails.application.routes.url_helpers }

  it "renders an inferred trait with evidence and source correction actions" do
    profile = create(:relationship_profile)
    memory = create(
      :memory_record,
      relationship_profile: profile,
      title: "Quiet birthday plans",
      body: "Smaller birthday dinners were well received.",
      source: "ai_inferred",
      confidence: "medium"
    )
    trait = RelationshipPersona.new(relationship_profile: profile).traits.sole

    render_inline(described_class.new(trait:, relationship_profile: profile))

    expect(page).to have_css("article.border-b.border-stone-200")
    expect(page).to have_css("span.bg-amber-50", text: "Inferred")
    expect(page).to have_text("Seems to suggest: Quiet birthday plans")
    expect(page).to have_text("Smaller birthday dinners were well received.")
    expect(page).to have_link("Review evidence", href: routes.relationship_profile_path(profile, anchor: ActionView::RecordIdentifier.dom_id(memory, :row)))
    expect(page).to have_link("Correct trait", href: routes.edit_relationship_profile_memory_record_path(profile, memory))
    expect(page.find_link("Review evidence")["data-turbo-frame"]).to eq("_top")
    expect(page.find_link("Correct trait")["data-turbo-frame"]).to eq(ActionView::RecordIdentifier.dom_id(memory))
  end

  it "links confirmed preferences back to the structured preference editor" do
    profile = create(:relationship_profile)
    preference = create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    trait = RelationshipPersona.new(relationship_profile: profile).traits.sole

    render_inline(described_class.new(trait:, relationship_profile: profile))

    expect(page).to have_css("span.bg-emerald-50", text: "Confirmed")
    expect(page).to have_link("Review evidence", href: routes.relationship_profile_path(profile, anchor: ActionView::RecordIdentifier.dom_id(preference, :persona_source)))
    expect(page).to have_link("Correct trait", href: routes.edit_relationship_profile_path(profile, anchor: ActionView::RecordIdentifier.dom_id(preference, :fields)))
    expect(page.find_link("Review evidence")["data-turbo-frame"]).to eq("_top")
    expect(page.find_link("Correct trait")["data-turbo-frame"]).to eq("_top")
  end
end
