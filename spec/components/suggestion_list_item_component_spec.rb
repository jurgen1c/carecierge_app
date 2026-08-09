require "rails_helper"

RSpec.describe SuggestionListItemComponent, type: :component do
  it "renders a selected inferred suggestion with accessible selection state" do
    suggestion = build_suggestion(certainty: "inferred")
    profile = create(:relationship_profile)

    render_inline(described_class.new(suggestion:, relationship_profile: profile, selected: true))

    expect(page).to have_link(suggestion.title, href: Rails.application.routes.url_helpers.relationship_profile_path(profile, suggestion: suggestion.fingerprint))
    expect(page).to have_css('[aria-current="true"]')
    expect(page).to have_css(".bg-amber-50")
  end

  def build_suggestion(certainty:)
    source = create(:relationship_preference, confidence: certainty)
    reason = Suggestion::Reason.new(
      label_key: "suggestions.reasons.relationship_context",
      label_params: {},
      evidence: source.value,
      certainty:,
      source:
    )
    Suggestion.new(
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
  end
end
