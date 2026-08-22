require "rails_helper"

RSpec.describe EventPlans::ContextBuilder do
  it "builds a bounded source catalog that includes approved relationship memories" do
    profile = create(:relationship_profile)
    memory = create(:memory_record, relationship_profile: profile, title: "Prefers quiet dinners", body: "Small groups feel more comfortable.")
    preference = create(:relationship_preference, relationship_profile: profile, key: "Food", value: "Vegetarian")
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)

    result = described_class.new(event_plan: plan).call

    expect(result.sources.map(&:id)).to include(
      "profile:#{profile.id}",
      "memory:#{memory.id}",
      "preference:#{preference.id}"
    )
    expect(result.fingerprint).to match(/\A[0-9a-f]{64}\z/)
  end

  it "excludes time-stale memories" do
    profile = create(:relationship_profile)
    current_memory = create(:memory_record, relationship_profile: profile, stale_after: Date.current)
    stale_memory = create(:memory_record, relationship_profile: profile, stale_after: Date.current - 1.day)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)

    result = described_class.new(event_plan: plan).call

    expect(result.sources.map(&:id)).to include("memory:#{current_memory.id}")
    expect(result.sources.map(&:id)).not_to include("memory:#{stale_memory.id}")
  end

  it "uses upcoming occurrences and excludes expired one-time dates" do
    Timecop.freeze(Time.zone.local(2026, 8, 21, 12)) do
      profile = create(:relationship_profile)
      expired = create(:important_date, relationship_profile: profile, starts_on: Date.new(2025, 8, 20), recurrence: "none")
      recurring = create(:important_date, relationship_profile: profile, starts_on: Date.new(2020, 8, 22), recurrence: "yearly")
      plan = create(:event_plan, user: profile.user, relationship_profile: profile)

      result = described_class.new(event_plan: plan).call
      recurring_source = result.sources.find { |source| source.id == "important_date:#{recurring.id}" }

      expect(result.sources.map(&:id)).not_to include("important_date:#{expired.id}")
      expect(recurring_source.content).to end_with("2026-08-22")
    end
  end

  it "evaluates stale memories and important dates on the owner's local calendar" do
    Timecop.freeze(Time.utc(2026, 8, 21, 6, 30)) do
      profile = create(:relationship_profile)
      create(
        :notification_preference,
        user: profile.user,
        time_zone: "America/Los_Angeles",
        time_zone_configured: true
      )
      local_today = Date.new(2026, 8, 20)
      memory = create(:memory_record, relationship_profile: profile, stale_after: local_today)
      important_date = create(
        :important_date,
        relationship_profile: profile,
        starts_on: local_today,
        recurrence: "none"
      )
      plan = create(:event_plan, user: profile.user, relationship_profile: profile)

      result = described_class.new(event_plan: plan).call

      expect(result.sources.map(&:id)).to include(
        "memory:#{memory.id}",
        "important_date:#{important_date.id}"
      )
    end
  end

  it "excludes private and vault content unless each source is explicitly selected" do
    profile = create(:relationship_profile)
    public_note = create(:relationship_note, relationship_profile: profile, private: false, body: "Public detail")
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Private detail")
    vault_item = create(
      :privacy_vault_item,
      relationship_profile: profile,
      suggestion_usage: "allowed",
      payload: { "title" => "Protected preference", "body" => "Vault detail" }
    )
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)

    default_result = described_class.new(event_plan: plan).call
    selected_result = described_class.new(
      event_plan: plan,
      private_note_ids: [ private_note.id ],
      vault_item_ids: [ vault_item.id ]
    ).call

    expect(default_result.sources.map(&:id)).to include("public_note:#{public_note.id}")
    expect(default_result.sources.map(&:id)).not_to include("private_note:#{private_note.id}", "vault:#{vault_item.id}")
    expect(selected_result.sources.select(&:sensitive).map(&:id)).to contain_exactly(
      "private_note:#{private_note.id}", "vault:#{vault_item.id}"
    )
  end

  it "fingerprints current plan details and tasks so concurrent edits supersede generation" do
    plan = create(:event_plan)
    task = create(:plan_task, event_plan: plan)
    initial = described_class.new(event_plan: plan).call.fingerprint

    task.update!(details: "A changed planning detail")

    expect(described_class.new(event_plan: plan.reload).call.fingerprint).not_to eq(initial)
  end

  it "preserves constraint certainty and optional planning context without inventing values" do
    profile = create(:relationship_profile)
    constraint = create(
      :relationship_preference,
      relationship_profile: profile,
      preference_type: "constraint",
      confidence: "confirmed",
      key: "Noise",
      value: "Keep it quiet"
    )
    inferred_memory = create(
      :memory_record,
      relationship_profile: profile,
      source: "ai_inferred",
      confidence: "medium"
    )
    create(:commitment, relationship_profile: profile, due_on: nil)
    create(:desire, relationship_profile: profile, source: "manual")
    plan = create(:event_plan, user: profile.user, relationship_profile: profile, starts_on: nil)
    create(:plan_task, event_plan: plan, due_on: nil, completed_at: nil)

    result = described_class.new(event_plan: plan).call
    constraint_source = result.sources.find { |source| source.id == "preference:#{constraint.id}" }
    memory_source = result.sources.find { |source| source.id == "memory:#{inferred_memory.id}" }

    expect(constraint_source).to have_attributes(kind: "constraint", certainty: "confirmed")
    expect(memory_source).to have_attributes(certainty: "inferred")
    expect(result.fingerprint).to match(/\A[0-9a-f]{64}\z/)
  end

  it "prioritizes category-based safety constraints even when their preference type is neutral" do
    profile = create(:relationship_profile)
    8.times do |index|
      create(
        :relationship_preference,
        relationship_profile: profile,
        key: "Ordinary #{index}",
        value: "Preference #{index}",
        preference_type: "positive"
      )
    end
    allergy = create(
      :relationship_preference,
      relationship_profile: profile,
      category: "allergies",
      preference_type: "neutral",
      key: "Peanuts",
      value: "Avoid entirely"
    )
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)

    source = described_class.new(event_plan: plan).call.sources.find do |candidate|
      candidate.id == "preference:#{allergy.id}"
    end

    expect(source).to have_attributes(kind: "constraint")
    expect(source.content).to include("allergies", "neutral", "Peanuts", "Avoid entirely")
  end

  it "marks protected AI-inferred memories as inferred sensitive sources" do
    profile = create(:relationship_profile)
    memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred")
    vault_item = create(
      :privacy_vault_item,
      relationship_profile: profile,
      protectable: memory,
      suggestion_usage: "allowed"
    )
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)

    result = described_class.new(event_plan: plan, vault_item_ids: [ vault_item.id ]).call

    expect(result.sources.find { |source| source.id == "vault:#{vault_item.id}" }).to have_attributes(
      certainty: "inferred",
      sensitive: true
    )
  end
end
