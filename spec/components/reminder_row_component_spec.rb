require "rails_helper"

RSpec.describe ReminderRowComponent, type: :component do
  it "renders timeline semantics, state text, and accessible actions" do
    reminder = build_stubbed(:reminder, title: "Call Elena", priority: "high", recurrence: "weekly")

    render_inline(described_class.new(reminder:))

    expect(page).to have_css("article[data-reminder-row]")
    expect(page).to have_text("Call Elena")
    expect(page).to have_text("High")
    expect(page).to have_text("Weekly")
    expect(page).to have_button("Complete")
    expect(page).to have_button("Snooze")
    expect(page).to have_link("Edit")
    expect(page).to have_link(
      "Export",
      href: Rails.application.routes.url_helpers.calendar_reminder_path(reminder, format: :ics)
    )
  end

  it "renders snoozed reminders at their effective delivery time" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    reminder = build_stubbed(
      :reminder,
      scheduled_at: now - 1.hour,
      snoozed_until: now + 1.day
    )

    Timecop.freeze(now) { render_inline(described_class.new(reminder:)) }

    expect(page).to have_css("time[datetime='#{(now + 1.day).iso8601}']")
    expect(page).not_to have_css("article.text-red-800")
  end
end
