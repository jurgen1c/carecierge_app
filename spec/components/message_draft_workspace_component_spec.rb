require "rails_helper"

RSpec.describe MessageDraftWorkspaceComponent, type: :component do
  it "renders the approved responsive workspace with editable content and immutable history" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    draft = create(:message_draft, user: profile.user, relationship_profile: profile)
    create(:draft_revision, message_draft: draft, position: 1, origin: "generated", content: "Happy birthday, Maya!")
    create(:draft_revision, message_draft: draft, position: 2, origin: "edited", content: "Wishing you a calm birthday, Maya!")

    render_inline described_class.new(
      relationship_profile: profile,
      message_draft: draft,
      revisions: draft.draft_revisions.to_a,
      context_categories: %w[profile preferences],
      private_notes_available: true,
      vault_items_available: true,
      vault_unlocked: false
    )

    expect(page).to have_css("#message-drafting")
    expect(page).to have_css("[class*='lg:grid-cols']")
    expect(page).to have_field("Message type", with: "birthday")
    expect(page).to have_field("Tone", with: "warm")
    expect(page).to have_field("Draft", with: "Wishing you a calm birthday, Maya!")
    expect(page).to have_content("Draft only — nothing will be sent")
    expect(page).to have_content("Revision history")
    expect(page).to have_button("Restore", count: 2)
    expect(page).to have_link("Unlock the privacy vault")
    expect(page).to have_unchecked_field("Use private notes for this draft")
    expect(page).to have_unchecked_field("Use vault items for this draft", disabled: true)
    expect(page).to have_no_button("Send")
  end

  it "renders bounded revision navigation without labeling an older page as current" do
    profile = create(:relationship_profile)
    draft = create(:message_draft, user: profile.user, relationship_profile: profile)
    revisions = [
      create(:draft_revision, message_draft: draft, position: 2),
      create(:draft_revision, message_draft: draft, position: 1)
    ]
    create(:draft_revision, message_draft: draft, position: 12, content: "Current revision")
    pagy = Pagy::Offset.new(count: 12, page: 2, limit: 10, page_key: "draft_page")

    render_inline described_class.new(
      relationship_profile: profile,
      message_draft: draft,
      revisions:,
      revisions_pagy: pagy
    )

    expect(page).to have_css("nav[aria-label='Revision history pages']")
    expect(page).to have_link("Previous")
    expect(page).to have_content("Page 2 of 2")
    expect(page).to have_no_css("span", text: "Current", exact_text: true)
  end

  it "renders localized empty-state controls without translation gaps" do
    profile = create(:relationship_profile)

    I18n.with_locale(:es) do
      render_inline described_class.new(
        relationship_profile: profile,
        message_draft: nil,
        revisions: [],
        context_categories: %w[profile],
        private_notes_available: false,
        vault_items_available: false,
        vault_unlocked: false
      )
    end

    expect(page).to have_content("Escribe con contexto")
    expect(page).to have_button("Generar borrador")
    expect(page).to have_no_content("Translation missing")
  end
end
