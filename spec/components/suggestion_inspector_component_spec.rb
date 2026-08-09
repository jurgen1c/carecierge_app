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
end
