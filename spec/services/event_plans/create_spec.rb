require "rails_helper"

RSpec.describe EventPlans::Create do
  it "creates an owner-scoped plan with a deterministic reusable template" do
    user = create(:user)
    profile = create(:relationship_profile, user:)

    plan = described_class.call(
      user:,
      relationship_profile: profile,
      attributes: {
        title: "Maya's birthday dinner",
        occasion_type: "birthday",
        starts_on: Date.new(2026, 9, 12),
        budget_cents: 15_000,
        guest_list: "Maya, Alex",
        notes: "Keep it relaxed."
      }
    )

    expect(plan).to be_persisted
    expect(plan.plan_tasks.pluck(:phase).uniq).to contain_exactly("decide", "arrange", "follow_through")
    expect(plan.plan_tasks.pluck(:kind)).to include(
      "decision", "task", "reminder", "vendor_need", "gift_idea", "message_draft", "backup_step", "milestone"
    )
    expect(plan.plan_tasks).to all(have_attributes(origin: "template", source_context: []))
  end

  it "supports birthday, anniversary, and custom occasions through the same model" do
    user = create(:user)
    profile = create(:relationship_profile, user:)

    %w[birthday anniversary custom].each do |occasion_type|
      plan = described_class.call(
        user:,
        relationship_profile: profile,
        attributes: { title: "Plan #{occasion_type}", occasion_type:, starts_on: Date.new(2026, 10, 1) }
      )

      expect(plan).to be_persisted
      expect(plan.plan_tasks).to be_present
    end
  end

  it "rejects cross-owner relationship context" do
    user = create(:user)
    profile = create(:relationship_profile)

    expect do
      described_class.call(
        user:,
        relationship_profile: profile,
        attributes: { title: "Private plan", occasion_type: "custom" }
      )
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects an archived relationship" do
    profile = create(:relationship_profile)
    profile.archive!

    expect do
      described_class.call(
        user: profile.user,
        relationship_profile: profile,
        attributes: { title: "Archived plan", occasion_type: "custom" }
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "revalidates birthday provenance after acquiring the relationship lock" do
    profile = create(:relationship_profile)
    important_date = create(:important_date, relationship_profile: profile, date_type: "birthday")
    important_date.update!(date_type: "anniversary")

    expect do
      described_class.call(
        user: profile.user,
        relationship_profile: profile,
        important_date_id: important_date.id,
        attributes: { title: "Birthday plan", occasion_type: "birthday" }
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
