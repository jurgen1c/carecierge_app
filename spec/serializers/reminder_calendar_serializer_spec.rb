require "rails_helper"

RSpec.describe ReminderCalendarSerializer do
  it "builds importable recurring VEVENT data with escaped private context" do
    reminder = build_stubbed(
      :reminder,
      id: "784e37f9-c82b-4f05-83f9-27a2f56033d4",
      title: "Dinner, then call",
      notes: "Bring flowers\nand a card",
      recurrence: "weekly",
      scheduled_at: Time.utc(2026, 7, 14, 22, 30)
    )

    calendar = described_class.new([ reminder ]).to_ical

    expect(calendar).to start_with("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n")
    expect(calendar).to include("BEGIN:VEVENT\r\n")
    expect(calendar).to include("UID:reminder-784e37f9-c82b-4f05-83f9-27a2f56033d4@carecierge\r\n")
    expect(calendar).to include("DTSTART:20260714T223000Z\r\n")
    expect(calendar).to include("SUMMARY:Dinner\\, then call\r\n")
    expect(calendar).to include("DESCRIPTION:Bring flowers\\nand a card\r\n")
    expect(calendar).to include("RRULE:FREQ=WEEKLY\r\n")
    expect(calendar).to include("CLASS:PRIVATE\r\n")
    expect(calendar).to end_with("END:VCALENDAR\r\n")
  end

  it "omits optional fields and folds long UTF-8 content on octet-safe boundaries" do
    title = "a" * 65 + "🎁" + "b" * 80
    reminder = build_stubbed(:reminder, title:, notes: nil, recurrence: "none")

    calendar = described_class.new(reminder).to_ical
    physical_lines = calendar.split("\r\n")
    summary_index = physical_lines.index { |line| line.start_with?("SUMMARY:") }
    summary_lines = physical_lines[summary_index..].take_while.with_index do |line, index|
      index.zero? || line.start_with?(" ")
    end

    expect(calendar).not_to include("DESCRIPTION:")
    expect(calendar).not_to include("RRULE:")
    expect(summary_lines.map(&:bytesize)).to all(be <= 75)
    unfolded_summary = summary_lines.first + summary_lines.drop(1).map { |line| line.delete_prefix(" ") }.join
    expect(unfolded_summary.delete_prefix("SUMMARY:")).to eq(title)
  end

  it "normalizes browser CRLF and bare carriage returns in private notes" do
    reminder = build_stubbed(:reminder, notes: "First line\r\nSecond line\rThird line")

    calendar = described_class.new(reminder).to_ical

    expect(calendar).to include("DESCRIPTION:First line\\nSecond line\\nThird line\r\n")
    expect(calendar.gsub("\r\n", "")).not_to include("\r")
  end

  it "anchors recurring events to their IANA timezone across DST" do
    zone = ActiveSupport::TimeZone["America/New_York"]
    reminder = build_stubbed(
      :reminder,
      recurrence: "weekly",
      time_zone: "America/New_York",
      scheduled_at: zone.local(2026, 3, 1, 9, 0)
    )

    calendar = described_class.new(reminder).to_ical

    expect(calendar).to include("BEGIN:VTIMEZONE\r\n")
    expect(calendar).to include("TZID:America/New_York\r\n")
    expect(calendar).to include("BEGIN:DAYLIGHT\r\n")
    expect(calendar).to include("TZOFFSETFROM:-0500\r\n")
    expect(calendar).to include("TZOFFSETTO:-0400\r\n")
    expect(calendar).to include("END:VTIMEZONE\r\n")
    expect(calendar).to include("DTSTART;TZID=America/New_York:20260301T090000\r\n")
    expect(calendar).to include("DTEND;TZID=America/New_York:20260301T093000\r\n")
    expect(calendar).to include("RRULE:FREQ=WEEKLY\r\n")
  end

  it "bases timezone transition coverage on recurring events rather than older one-time reminders" do
    zone = ActiveSupport::TimeZone["America/New_York"]
    one_time = build_stubbed(
      :reminder,
      recurrence: "none",
      time_zone: "America/New_York",
      scheduled_at: zone.local(2000, 1, 1, 9, 0)
    )
    recurring = build_stubbed(
      :reminder,
      recurrence: "weekly",
      time_zone: "America/New_York",
      scheduled_at: zone.local(2040, 1, 1, 9, 0)
    )

    timezone_definition = described_class.new([ one_time, recurring ]).to_ical.split("END:VTIMEZONE").first

    expect(timezone_definition).to include("DTSTART:2040")
  end

  it "exports a snoozed one-time reminder at its effective time" do
    reminder = build_stubbed(
      :reminder,
      recurrence: "none",
      scheduled_at: Time.utc(2026, 7, 14, 9, 0),
      snoozed_until: Time.utc(2026, 7, 15, 14, 30)
    )

    calendar = described_class.new(reminder).to_ical

    expect(calendar).to include("DTSTART:20260715T143000Z\r\n")
    expect(calendar).not_to include("DTSTART:20260714T090000Z\r\n")
  end
end
