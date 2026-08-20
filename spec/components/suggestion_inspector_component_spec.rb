require "rails_helper"

RSpec.describe SuggestionInspectorComponent, type: :component do
  it "renders the explanation, source certainty, feedback, and reminder-only action" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    source = create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    reason = Suggestion::Reason.new(
      label_key: "suggestions.reasons.relationship_context",
      label_params: {},
      evidence: "Short and sincere messages",
      certainty: "confirmed",
      source:
    )
    suggestion = Suggestion.new(
      fingerprint: "fingerprint",
      suggestion_type: "message",
      title_key: "suggestions.types.message.title",
      title_params: { name: "Maya" },
      detail_key: "suggestions.types.message.detail",
      detail_params: { name: "Maya" },
      reasons: [ reason ],
      action_kind: "create_reminder",
      action_attributes: {}
    )

    render_inline(described_class.new(suggestion:, relationship_profile: profile, feedback: nil))

    expect(page).to have_text("Why this appears")
    expect(page).to have_text("Short and sincere messages")
    expect(page).to have_text("Confirmed")
    expect(page).to have_css(".bg-emerald-50.text-emerald-900", text: "Confirmed")
    expect(page).to have_button("Create reminder")
    expect(page).to have_button("Helpful")
    expect(page).to have_button("Not for me")
    expect(page).to have_button("Dismiss")
    expect(page).to have_text("This creates a private reminder for you. It does not contact anyone automatically.")
  end

  it "renders gesture effort, save, complete, and alternative controls" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    reason = Suggestion::Reason.new(
      label_key: "suggestions.reasons.spontaneous",
      label_params: { name: "Maya" },
      evidence: profile.relationship_type_label,
      certainty: "confirmed",
      source: profile
    )
    suggestion = Suggestion.new(
      fingerprint: "gesture-fingerprint",
      suggestion_type: "spontaneous",
      title_key: "suggestions.types.spontaneous.low.title",
      title_params: { name: "Maya" },
      detail_key: "suggestions.types.spontaneous.low.detail",
      detail_params: { name: "Maya" },
      reasons: [ reason ],
      action_kind: "create_reminder",
      action_attributes: {},
      effort: "low",
      variation: "low"
    )

    render_inline(described_class.new(suggestion:, relationship_profile: profile, feedback: nil))

    expect(page).to have_text("Low effort")
    expect(page).to have_button("Save")
    expect(page).to have_button("Mark complete")
    expect(page).to have_link("Show another", href: Rails.application.routes.url_helpers.relationship_profile_path(
      profile,
      gesture: "medium",
      suggestion_type: "spontaneous"
    ))
  end

  it "links recent-interaction evidence to the rendered interaction frame" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    interaction = create(:interaction, relationship_profile: profile)
    reason = Suggestion::Reason.new(
      label_key: "suggestions.reasons.spontaneous",
      label_params: { name: "Maya" },
      evidence: "Recent call",
      certainty: "confirmed",
      source: interaction
    )
    suggestion = Suggestion.new(
      fingerprint: "gesture-fingerprint",
      suggestion_type: "spontaneous",
      title_key: "suggestions.types.spontaneous.low.title",
      title_params: { name: "Maya" },
      detail_key: "suggestions.types.spontaneous.low.detail",
      detail_params: { name: "Maya" },
      reasons: [ reason ],
      action_kind: "create_reminder",
      action_attributes: {},
      effort: "low",
      variation: "low"
    )

    render_inline(described_class.new(suggestion:, relationship_profile: profile, feedback: nil))

    expect(page).to have_link(
      "View source: recent interaction",
      href: Rails.application.routes.url_helpers.relationship_profile_path(
        profile,
        anchor: ActionView::RecordIdentifier.dom_id(interaction)
      )
    )
  end
end
