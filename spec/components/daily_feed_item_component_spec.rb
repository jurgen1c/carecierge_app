require "rails_helper"

RSpec.describe DailyFeedItemComponent, type: :component do
  it "renders source context and accessible source and feed actions" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Taylor")
    reminder = create(:reminder, user:, relationship_profile: profile, title: "Call Taylor", notes: "Share the introduction.")
    item = DailyFeed::Item.new(
      key: "reminder:#{reminder.id}",
      kind: "reminder",
      section: "needs_attention",
      title: reminder.title,
      detail: reminder.notes,
      source_label: "Reminder",
      source_context: reminder.notes,
      source_certainty: nil,
      source: reminder,
      relationship_profile: profile,
      sort_at: reminder.effective_delivery_at,
      action_kind: "complete_reminder",
      suggestion: nil
    )

    render_inline(described_class.new(item:, featured: true))

    expect(page).to have_css("article[data-feed-item-key='#{item.key}']")
    expect(page).to have_text("Call Taylor")
    expect(page).to have_text("Share the introduction.")
    expect(page).to have_text("Source context")
    expect(page).to have_button("Complete")
    expect(page).to have_button("Snooze")
    expect(page).to have_button("Dismiss")
    expect(page).to have_css("span", text: "Needs attention")
    expect(page).not_to have_css(".bg-danger-surface, .text-danger-ink")
    expect(page).to have_css("h3.break-words", text: "Call Taylor")
    expect(page).to have_css("details p.break-words", text: "Share the introduction.")
    expect(page).not_to have_css("[class*='emerald-'], [class*='amber-']")
    expect(page.find("form[action='#{Rails.application.routes.url_helpers.complete_reminder_path(reminder)}']")["data-turbo"]).to eq("false")
    expect(page).to have_link(
      "Open Taylor's profile",
      href: Rails.application.routes.url_helpers.relationship_profile_path(profile)
    )
  end

  it "links message drafts to the existing workspace anchor" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    item = DailyFeed::Item.new(
      key: "message_draft:#{draft.id}",
      kind: "message_draft",
      section: "later_today",
      title: "Continue draft",
      detail: "Review before sending",
      source_label: "Message draft",
      source_context: "Draft context",
      source_certainty: nil,
      source: draft,
      relationship_profile: profile,
      sort_at: draft.updated_at,
      action_kind: "open_message_draft",
      suggestion: nil
    )

    render_inline(described_class.new(item:))

    expect(page).to have_link("Open draft", href: Rails.application.routes.url_helpers.relationship_profile_path(profile, anchor: "message-drafting"))
  end

  it "uses the first alphabetic character of each relationship name part for initials" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "2Pac !Shakur")
    reminder = create(:reminder, user:, relationship_profile: profile)
    item = DailyFeed::Item.new(
      key: "reminder:#{reminder.id}",
      kind: "reminder",
      section: "later_today",
      title: reminder.title,
      detail: reminder.notes,
      source_label: "Reminder",
      source_context: reminder.notes,
      source_certainty: nil,
      source: reminder,
      relationship_profile: profile,
      sort_at: reminder.effective_delivery_at,
      action_kind: "complete_reminder",
      suggestion: nil
    )

    render_inline(described_class.new(item:))

    expect(page).to have_css("[aria-hidden='true']", text: "PS")
  end


  it "labels inferred suggestion evidence" do
    profile = create(:relationship_profile)
    item = DailyFeed::Item.new(
      key: "suggestion:inferred",
      kind: "suggestion",
      section: "later_today",
      title: "Send a thoughtful check-in",
      detail: "A short note may help.",
      source_label: "Suggestion",
      source_context: "Short messages may feel easier.",
      source_certainty: "inferred",
      source: create(:relationship_preference, relationship_profile: profile),
      relationship_profile: profile,
      sort_at: Time.current,
      action_kind: nil,
      suggestion: nil
    )

    render_inline(described_class.new(item:))

    expect(page).to have_text("Inferred")
  end
end
