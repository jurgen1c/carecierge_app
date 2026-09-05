require "rails_helper"

RSpec.describe CalendarSyncs::Event do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, preferred_name: "Maya") }

  it "maps all supported private source types without sending private notes or locations" do
    sources = [
      create(:important_date, relationship_profile: profile, title: "Milestone", notes: "Private date note"),
      create(:reminder, user:, relationship_profile: profile, title: "Call Maya", notes: "Private reminder note"),
      create(:event_plan, user:, relationship_profile: profile, title: "Birthday dinner", notes: "Private plan note"),
      create(:booking, user:, event_plan: create(:event_plan, user:, relationship_profile: profile), title: "Dinner", location: "Private address"),
      create(:commitment, relationship_profile: profile, title: "Send the article", notes: "Private commitment note")
    ]

    events = sources.map { |source| described_class.new(source:) }

    expect(events.map(&:sync_type)).to contain_exactly(*CalendarConnection::SYNC_TYPES)
    events.each do |event|
      expect(event.attributes).to include(visibility: "private")
      expect(event.attributes.to_json).not_to include("Private date note", "Private reminder note", "Private plan note", "Private address", "Private commitment note")
      expect(event.fingerprint).to match(/\A[0-9a-f]{64}\z/)
    end
  end

  it "uses all-day dates and timed booking/reminder events" do
    date = create(:important_date, relationship_profile: profile, starts_on: Date.new(2026, 9, 8))
    booking = create(:booking, user:, event_plan: create(:event_plan, user:, relationship_profile: profile), starts_at: Time.utc(2026, 9, 9, 18), time_zone: "America/Costa_Rica")

    expect(described_class.new(source: date).attributes).to include(
      start: { date: "2026-09-08" }, end: { date: "2026-09-09" }
    )
    expect(described_class.new(source: booking).attributes.dig(:start, :time_zone)).to eq("America/Costa_Rica")
  end

  it "uses the connection locale for generated titles regardless of the job locale" do
    date = create(:important_date, relationship_profile: profile, date_type: "birthday", title: nil)

    spanish_job_fingerprint = I18n.with_locale(:es) { described_class.new(source: date, locale: :es).fingerprint }
    english_job_event = I18n.with_locale(:en) { described_class.new(source: date, locale: :es) }

    expect(english_job_event.attributes.fetch(:summary)).to eq(I18n.t("important_dates.date_types.birthday", locale: :es))
    expect(english_job_event.fingerprint).to eq(spanish_job_fingerprint)
  end

  it "uses the effective delivery time for a snoozed one-time reminder" do
    reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      recurrence: "none",
      scheduled_at: Time.utc(2026, 9, 9, 18),
      snoozed_until: Time.utc(2026, 9, 10, 20),
      time_zone: "America/Costa_Rica"
    )

    event = described_class.new(source: reminder)

    expect(event.attributes.dig(:start, :date_time)).to eq("2026-09-10T14:00:00-06:00")
    expect(event.attributes.dig(:end, :date_time)).to eq("2026-09-10T14:30:00-06:00")
  end

  it "enumerates monthly and yearly dates whose recurrence clamps to month end" do
    monthly = create(:important_date, relationship_profile: profile, starts_on: Date.new(2026, 1, 31), recurrence: "monthly")
    yearly = create(:important_date, relationship_profile: profile, starts_on: Date.new(2024, 2, 29), recurrence: "yearly")

    expect(described_class.new(source: monthly).attributes.fetch(:recurrence).first)
      .to start_with("RDATE;VALUE=DATE:20260228,20260331")
    expect(described_class.new(source: yearly).attributes.fetch(:recurrence).first)
      .to start_with("RDATE;VALUE=DATE:20250228,20260228")
  end

  it "keeps future clamped occurrences when an important date began over a century ago" do
    date = create(:important_date, relationship_profile: profile, starts_on: Date.new(1920, 2, 29), recurrence: "yearly")

    Timecop.freeze(Time.zone.local(2026, 9, 4, 12)) do
      recurrence = described_class.new(source: date).attributes.fetch(:recurrence).first

      expect(recurrence).to include("20270228")
    end
  end

  it "enumerates monthly and yearly reminders whose recurrence clamps to month end" do
    monthly = create(
      :reminder,
      user:,
      relationship_profile: profile,
      recurrence: "monthly",
      scheduled_at: Time.utc(2026, 1, 31, 15)
    )
    yearly = create(
      :reminder,
      user:,
      relationship_profile: profile,
      recurrence: "yearly",
      scheduled_at: Time.utc(2024, 2, 29, 15)
    )

    expect(described_class.new(source: monthly).attributes.fetch(:recurrence).first)
      .to start_with("RDATE:20260228T150000Z,20260331T150000Z")
    expect(described_class.new(source: yearly).attributes.fetch(:recurrence).first)
      .to start_with("RDATE:20250228T150000Z,20260228T150000Z")
  end

  it "keeps future clamped occurrences when a reminder anchor is over a century old" do
    reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      recurrence: "yearly",
      scheduled_at: Time.utc(1920, 2, 29, 15)
    )

    Timecop.freeze(Time.zone.local(2026, 9, 4, 12)) do
      recurrence = described_class.new(source: reminder).attributes.fetch(:recurrence).first

      expect(recurrence).to include("20270228T150000Z")
    end
  end
end
