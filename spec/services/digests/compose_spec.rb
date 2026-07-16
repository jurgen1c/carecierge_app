require "rails_helper"

RSpec.describe Digests::Compose do
  it "builds a concise owner-scoped digest from commitments, dates, planning prompts, and check-ins" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    commitment_profile = create(:relationship_profile, user:, preferred_name: "David")
    date_profile = create(:relationship_profile, user:, preferred_name: "Ana")
    planning_profile = create(:relationship_profile, user:, preferred_name: "Marta")
    check_in_profile = create(:relationship_profile, user:, preferred_name: "Carlos", created_at: now - 8.days)
    create(:commitment, relationship_profile: commitment_profile, title: "Send the book recommendation", due_on: now.to_date - 3.days)
    create(:important_date, relationship_profile: date_profile, title: "Birthday", starts_on: now.to_date + 2.days, recurrence: "none")
    create(:important_date, relationship_profile: planning_profile, title: "Anniversary", starts_on: now.to_date + 20.days, recurrence: "none")
    create(:contact_cadence, relationship_profile: check_in_profile, interval_days: 7, created_at: now - 8.days)
    create(:relationship_profile, preferred_name: "Someone else")

    digest = described_class.call(user:, as_of: now, mode: "weekly")

    expect(digest.items.map(&:kind)).to contain_exactly(:commitment, :upcoming_date, :planning_prompt, :check_in)
    expect(digest.items.map(&:relationship_name)).to contain_exactly("David", "Ana", "Marta", "Carlos")
    expect(digest.items.first).to have_attributes(kind: :commitment, overdue: true)
  end

  it "excludes muted and archived relationships and caps noisy digests" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    preference = create(:notification_preference, user:)
    muted = create(:relationship_profile, user:, preferred_name: "Muted")
    archived = create(:relationship_profile, user:, preferred_name: "Archived", discarded_at: now)
    create(:commitment, relationship_profile: muted, due_on: now.to_date)
    create(:commitment, relationship_profile: archived, due_on: now.to_date)
    create(:relationship_notification_preference, notification_preference: preference, relationship_profile: muted)
    10.times do |index|
      profile = create(:relationship_profile, user:, preferred_name: "Person #{index}")
      create(:commitment, relationship_profile: profile, title: "Action #{index}", due_on: now.to_date + index.days)
    end

    digest = described_class.call(user:, as_of: now, mode: "weekly")

    expect(digest.items.size).to eq(8)
    expect(digest.items.map(&:relationship_name)).not_to include("Muted", "Archived")
  end

  it "preserves the supplied local calendar date across a UTC date boundary" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    as_of = zone.local(2026, 7, 15, 23, 0)
    user = create(:user)
    today = create(:relationship_profile, user:, preferred_name: "Today")
    tomorrow = create(:relationship_profile, user:, preferred_name: "Tomorrow")
    create(:commitment, relationship_profile: today, title: "Due locally today", due_on: Date.new(2026, 7, 15))
    create(:commitment, relationship_profile: tomorrow, title: "Due locally tomorrow", due_on: Date.new(2026, 7, 16))

    digest = described_class.call(user:, as_of:, mode: "daily")

    expect(digest.as_of.to_date).to eq(Date.new(2026, 7, 15))
    expect(digest.items.map(&:title)).to eq([ "Due locally today" ])
  end

  it "uses the recipient time zone for the daily check-in horizon" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    as_of = zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Evening check-in")
    create(:contact_cadence, relationship_profile: profile, interval_days: 7, created_at: zone.local(2026, 7, 8, 20, 0))

    digest = described_class.call(user:, as_of:, mode: "daily")

    expect(digest.items.map(&:kind)).to eq([ :check_in ])
  end

  it "uses the latest interaction when calculating contact cadence" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Recently contacted")
    create(:contact_cadence, relationship_profile: profile, interval_days: 7, created_at: now - 30.days)
    create(:interaction, relationship_profile: profile, occurred_at: now - 20.days)
    create(:interaction, relationship_profile: profile, occurred_at: now - 2.days)

    digest = described_class.call(user:, as_of: now, mode: "daily")

    expect(digest.items).to be_empty
  end
end
