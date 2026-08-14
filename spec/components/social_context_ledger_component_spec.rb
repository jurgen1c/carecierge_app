require "rails_helper"

RSpec.describe SocialContextLedgerComponent, type: :component do
  it "renders the approved compact ledger with an inline Lexxy composer and explicit trust controls" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    note = create(
      :social_context_note,
      relationship_profile: profile,
      body: "Maya posted about a neighborhood bookstore event.",
      allow_suggestions: false
    )
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("analyze_uploaded_social_content"),
      mode: "ask_every_time"
    )

    render_inline described_class.new(
      relationship_profile: profile,
      notes: [ note ],
      new_note: profile.social_context_notes.new,
      analysis_permission: permission
    )

    expect(page).to have_css("section#social-context")
    expect(page).to have_content("Only context you add appears here")
    expect(page).to have_content("Added by you")
    expect(page).to have_css("details", count: 2)
    expect(page).to have_css("lexxy-editor[name='social_context_note[body]']", count: 2, visible: :all)
    expect(page.all("lexxy-editor", visible: :all).map { |editor| editor[:id] }).to contain_exactly(
      "social_context_note_#{note.id}_body",
      "social_context_note_new_body"
    )
    expect(page).to have_field("Use in suggestions and message drafts", checked: false, count: 2, visible: :all)
    expect(page).to have_css(
      "input[type='hidden'][name='social_context_note[lock_version]'][value='#{note.lock_version}']",
      visible: :all
    )
    expect(page).to have_css(
      "form[action='#{Rails.application.routes.url_helpers.relationship_profile_social_context_note_path(profile, note)}'] " \
        "button[name='intent'][value='analyze']",
      visible: :all
    )
    expect(page).to have_button("Save and analyze", visible: :all)
    expect(page).to have_css("p", text: "Provider safety retention may apply", visible: :all)
    expect(page).to have_button("Delete note", visible: :all)
    expect(rendered_content).to include(
      "bg-primary",
      "border-private-line",
      "text-danger-ink",
      "focus-visible:outline-primary"
    )
    expect(rendered_content).not_to match(/(?:emerald|red)-\d/)
  end

  it "shows a reviewable interpretation draft and Spanish copy without translation gaps" do
    profile = create(:relationship_profile)
    note = create(
      :social_context_note,
      relationship_profile: profile,
      interpretation: "This may be a comfortable conversation topic.",
      interpretation_status: "draft",
      suggested_uses: %w[conversation_topic]
    )
    permission = AutomationPermissionDecision.new(
      capability: AutomationCapability.fetch("analyze_uploaded_social_content"),
      mode: "disabled"
    )

    I18n.with_locale(:es) do
      render_inline described_class.new(
        relationship_profile: profile,
        notes: [ note ],
        new_note: profile.social_context_notes.new,
        analysis_permission: permission
      )
    end

    expect(page).to have_content("Contexto social")
    expect(page).to have_content("Borrador de interpretación de Carecierge")
    expect(page).to have_field("Interpretación", with: "This may be a comfortable conversation topic.")
    expect(page).to have_field("Tema de conversación", checked: true)
    expect(page).to have_field("Regalo", checked: false)
    expect(page).to have_link("Revisar permiso de análisis")
    expect(page).to have_link(
      "Revisar permiso de análisis",
      href: Rails.application.routes.url_helpers.edit_automation_permissions_path(
        capability: "analyze_uploaded_social_content",
        anchor: "capability-panel-analyze_uploaded_social_content"
      )
    )
    expect(page).to have_css("p", text: "retención de seguridad del proveedor", visible: :all)
    expect(page).to have_no_content("Translation missing")
  end
end
