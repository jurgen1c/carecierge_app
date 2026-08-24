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


  it "includes explicitly selected prior anniversary context as untrusted history that needs confirmation" do
    profile = create(:relationship_profile)
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      title: "Last year's quiet dinner",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create(:plan_task, event_plan: prior_plan, title: "Booked a quiet table", completed_at: 1.year.ago)
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )

    source = described_class.new(event_plan: plan).call.sources.find { |candidate| candidate.kind == "prior_anniversary_plan" }

    expect(source).to have_attributes(kind: "prior_anniversary_plan", certainty: "inferred", sensitive: false)
    expect(source.content).to include("Last year's quiet dinner", "Booked a quiet table")

    without_selection = create(:event_plan, user: profile.user, relationship_profile: profile, occasion_type: "anniversary")
    expect(described_class.new(event_plan: without_selection).call.sources.map(&:kind)).not_to include("prior_anniversary_plan")
  end

  it "marks prior-plan summaries sensitive when included task copy depends on selected sensitive context" do
    profile = create(:relationship_profile)
    private_note = create(
      :relationship_note,
      relationship_profile: profile,
      private: true,
      body: "A private anniversary detail"
    )
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      title: "Last year's plan",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create(
      :plan_task,
      event_plan: prior_plan,
      title: "Reuse the private anniversary detail",
      origin: "ai",
      source_context: [
        {
          "id" => "private_note:#{private_note.id}",
          "label" => "Private note",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )

    source = described_class.new(event_plan: plan, private_note_ids: [ private_note.id ]).call.sources.find do |candidate|
      candidate.kind == "prior_anniversary_plan"
    end

    expect(source).to have_attributes(sensitive: true)
    expect(source.content).to include("Reuse the private anniversary detail")
  end

  it "changes prior-plan evidence when an authorized dependency changes in place" do
    profile = create(:relationship_profile)
    private_note = create(
      :relationship_note,
      relationship_profile: profile,
      private: true,
      body: "Original private anniversary detail"
    )
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      title: "Last year's plan",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create(
      :plan_task,
      event_plan: prior_plan,
      title: "Reuse the original private detail",
      origin: "ai",
      source_context: [
        {
          "id" => "private_note:#{private_note.id}",
          "label" => "Private note",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )

    original_source = described_class.new(
      event_plan: plan,
      private_note_ids: [ private_note.id ]
    ).call.sources.find { |candidate| candidate.kind == "prior_anniversary_plan" }
    private_note.update!(body: "Corrected private anniversary detail")
    corrected_source = described_class.new(
      event_plan: plan,
      private_note_ids: [ private_note.id ]
    ).call.sources.find { |candidate| candidate.kind == "prior_anniversary_plan" }

    expect(corrected_source.id).not_to eq(original_source.id)
  end

  it "keeps every current safety constraint ahead of prior history when the context budget is saturated" do
    profile = create(:relationship_profile)
    private_notes = create_list(
      :relationship_note,
      described_class::MAX_PER_KIND,
      relationship_profile: profile,
      private: true,
      body: "P" * 1_000
    )
    vault_items = create_list(
      :privacy_vault_item,
      described_class::MAX_PER_KIND,
      relationship_profile: profile,
      suggestion_usage: "allowed",
      payload: { "title" => "Protected detail", "body" => "V" * 1_000 }
    )
    constraints = described_class::MAX_PER_KIND.times.map do |index|
      create(
        :relationship_preference,
        relationship_profile: profile,
        category: "allergies",
        preference_type: "constraint",
        key: "Safety constraint #{index}",
        value: "C" * 1_000
      )
    end
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      title: "Last year's plan",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    6.times do |index|
      create(:plan_task, event_plan: prior_plan, title: "Historical task #{index} #{"H" * 180}")
    end
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )

    source_ids = described_class.new(
      event_plan: plan,
      private_note_ids: private_notes.map(&:id),
      vault_item_ids: vault_items.map(&:id)
    ).call.sources.map(&:id)

    expect(source_ids).to include(*constraints.map { |constraint| "preference:#{constraint.id}" })
  end

  it "does not carry sensitive AI-derived task copy through prior anniversary history" do
    profile = create(:relationship_profile)
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      title: "Last year's plan",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create(:plan_task, event_plan: prior_plan, title: "Keep the handwritten note", origin: "manual")
    create(
      :plan_task,
      event_plan: prior_plan,
      title: "Use the private medical detail",
      origin: "ai",
      source_context: [
        {
          "id" => "vault:#{SecureRandom.uuid}",
          "label" => "Private health context",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )

    source = described_class.new(event_plan: plan).call.sources.find { |candidate| candidate.kind == "prior_anniversary_plan" }

    expect(source.content).to include("Last year's plan", "Keep the handwritten note")
    expect(source.content).not_to include("Use the private medical detail")
    expect(source).to have_attributes(sensitive: false)
  end

  it "does not reuse historical AI task copy after its source becomes protected" do
    profile = create(:relationship_profile)
    memory = create(
      :memory_record,
      relationship_profile: profile,
      title: "Private anniversary detail",
      body: "This should require fresh vault authorization."
    )
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      title: "Last year's plan",
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create(
      :plan_task,
      event_plan: prior_plan,
      title: "Reuse the protected anniversary detail",
      origin: "ai",
      source_context: [
        {
          "id" => "memory:#{memory.id}",
          "label" => "Relationship memory",
          "certainty" => "confirmed",
          "sensitive" => false
        }
      ]
    )
    PrivacyVault::Protect.call(actor: profile.user, protectable: memory)
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )

    source = described_class.new(event_plan: plan).call.sources.find { |candidate| candidate.kind == "prior_anniversary_plan" }

    expect(source.content).to include("Last year's plan")
    expect(source.content).not_to include("Reuse the protected anniversary detail")
  end

  it "limits prior anniversary task candidates in the database" do
    profile = create(:relationship_profile)
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      status: "completed",
      completed_at: 1.year.ago
    )
    create_list(:plan_task, 51, event_plan: prior_plan)
    plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
      occasion_type: "anniversary",
      source_context: [
        {
          "id" => "event_plan:#{prior_plan.id}",
          "label" => "Prior anniversary plan — review before reusing",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )
    task_queries = []
    capture = lambda do |_name, _started, _finished, _unique_id, payload|
      task_queries << payload[:sql] if payload[:name] == "PlanTask Load"
    end

    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") do
      described_class.new(event_plan: plan).send(:prior_anniversary_plan_sources, authorized_source_ids: {})
    end

    expect(task_queries).not_to be_empty
    expect(task_queries).to all(match(/LIMIT/))
  end
end
