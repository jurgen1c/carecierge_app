require "rails_helper"

RSpec.describe Today::Overview do
  let(:now) { Time.zone.local(2026, 9, 7, 10) }
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  around { |example| Timecop.freeze(now, &example) }

  it "keeps optional ideas separate from dated work" do
    create(:gift, relationship_profile: profile, name: "A book to consider", status: "idea")
    create(:reminder, user:, relationship_profile: profile, title: "Call today", scheduled_at: now + 2.hours)

    overview = described_class.new(user:)
    expect(overview.feed.later_today.map(&:title)).to include("Call today")
    expect(overview.feed.later_today.map(&:title)).not_to include("A book to consider")
    expect(overview.feed.ideas.map(&:title)).to include("A book to consider")
  end

  it "shows upcoming active plans only for the owner and active relationships" do
    plan = create(:event_plan, user:, relationship_profile: profile, starts_on: now.to_date + 3.days)
    create(:event_plan, starts_on: now.to_date + 2.days)
    archived = create(:relationship_profile, user:, discarded_at: now)
    create(:event_plan, user:, relationship_profile: archived, starts_on: now.to_date + 2.days)
    create(:event_plan, user:, relationship_profile: profile, starts_on: now.to_date + 40.days)

    expect(described_class.new(user:).plans).to eq([ plan ])
  end

  it "grounds check-ins in the saved cadence and most recent interaction" do
    cadence = create(:contact_cadence, relationship_profile: profile, interval_days: 7, created_at: now - 10.days)
    expect(described_class.new(user:).check_ins).to include(cadence)
    create(:interaction, relationship_profile: profile, occurred_at: now - 1.day)
    expect(described_class.new(user:).check_ins).to be_empty
  end

  it "bounds previews while retaining the actual plan count" do
    7.times { |index| create(:event_plan, user:, relationship_profile: profile, starts_on: now.to_date + index.days) }
    overview = described_class.new(user:)
    expect(overview.plans.size).to eq(4)
    expect(overview.plan_count).to eq(7)
    expect(overview.profile_count).to eq(1)
  end

  it "does not count another owner's pending reviews" do
    create(:approval_request)
    own = create(:approval_request, user:, subject: create(:extracted_memory, relationship_profile: profile))
    overview = described_class.new(user:)
    expect(overview.review_count).to eq(1)
    own.update!(status: "deferred", deferred_until: now + 1.day)
    expect(described_class.new(user:).review_count).to eq(0)
  end
end
