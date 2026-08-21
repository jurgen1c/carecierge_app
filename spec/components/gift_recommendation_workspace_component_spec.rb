require "rails_helper"

RSpec.describe GiftRecommendationWorkspaceComponent, type: :component do
  it "renders source-backed recommendations and explicit review actions with the design-system palette" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("suggest_gifts"),
      mode: "ask_every_time"
    )
    recommendation = create(:gift_recommendation, user: profile.user, relationship_profile: profile)

    render_inline described_class.new(
      relationship_profile: profile,
      recommendations: [ recommendation ],
      permission:,
      private_notes_available: true,
      vault_items_available: true,
      vault_unlocked: false
    )

    expect(page).to have_css("#gift-recommendations")
    expect(page).to have_field("Maximum budget")
    expect(page).to have_unchecked_field("Include private notes")
    expect(page).to have_unchecked_field("Include Privacy Vault context", disabled: true)
    expect(page).to have_link(
      "Unlock the Privacy Vault",
      href: Rails.application.routes.url_helpers.relationship_profile_privacy_vault_path(profile)
    )
    expect(page).to have_unchecked_field("Allow repeatable staples")
    expect(page).to have_content("Coffee tasting set")
    expect(page).to have_content("Preference")
    expect(page).to have_content("Confirmed")
    expect(page).to have_button("Save idea")
    expect(page).to have_button("Mark purchased")
    expect(page).to have_button("Try an alternative")
    expect(page).to have_button("Dismiss")
    expect(rendered_content).to include("bg-primary", "border-private-line")
    expect(rendered_content).not_to match(/(?:emerald|red)-\d/)
  end

  it "renders localized copy in Spanish" do
    profile = create(:relationship_profile)
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("suggest_gifts"),
      mode: "allow_automatically"
    )

    I18n.with_locale(:es) do
      render_inline described_class.new(relationship_profile: profile, permission:)
    end

    expect(page).to have_content("Recomendaciones de regalos")
    expect(page).to have_button("Recomendar regalos")
    expect(page).to have_no_content("Translation missing")
  end

  it "keeps stored recommendations reviewable when new generation is disabled" do
    profile = create(:relationship_profile)
    recommendation = create(:gift_recommendation, user: profile.user, relationship_profile: profile)
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("suggest_gifts"),
      mode: "disabled"
    )

    render_inline described_class.new(
      relationship_profile: profile,
      recommendations: [ recommendation ],
      permission:
    )

    expect(page).to have_content(recommendation.title)
    expect(page).to have_button("Save idea")
    expect(page).to have_button("Mark purchased")
    expect(page).to have_button("Dismiss")
    expect(page).to have_no_button("Try an alternative")
    expect(page).to have_no_button("Recommend gifts")
    expect(page).to have_link("Review gift suggestion controls")
  end

  it "asks for fresh consent before an alternative reuses sensitive context" do
    profile = create(:relationship_profile)
    recommendation = create(
      :gift_recommendation,
      user: profile.user,
      relationship_profile: profile,
      source_context: [
        {
          "id" => "private_note:#{SecureRandom.uuid}",
          "label" => "Private note",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("suggest_gifts"),
      mode: "allow_automatically"
    )

    render_inline described_class.new(relationship_profile: profile, recommendations: [ recommendation ], permission:)

    expect(page).to have_unchecked_field("Reuse private notes for this alternative")
    expect(page).to have_button("Try an alternative")
  end

  it "keeps vault reuse unavailable and exposes the unlock path when the lease is locked" do
    profile = create(:relationship_profile)
    recommendation = create(
      :gift_recommendation,
      user: profile.user,
      relationship_profile: profile,
      source_context: [
        {
          "id" => "vault:#{SecureRandom.uuid}",
          "label" => "Privacy Vault item",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("suggest_gifts"),
      mode: "allow_automatically"
    )

    render_inline described_class.new(
      relationship_profile: profile,
      recommendations: [ recommendation ],
      permission:,
      vault_unlocked: false
    )

    expect(page).to have_unchecked_field("Reuse Privacy Vault context for this alternative", disabled: true)
    expect(page).to have_link(
      "Unlock the Privacy Vault",
      href: Rails.application.routes.url_helpers.relationship_profile_privacy_vault_path(profile)
    )
  end

  it "uses the owner's local date as the generation minimum" do
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    profile = create(:relationship_profile, user:)
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("suggest_gifts"),
      mode: "allow_automatically"
    )

    Timecop.freeze(Time.utc(2026, 8, 20, 1, 30)) do
      render_inline described_class.new(relationship_profile: profile, permission:)
    end

    expect(page).to have_css('input[type="date"][min="2026-08-19"][max="9999-12-31"]')
  end
end
