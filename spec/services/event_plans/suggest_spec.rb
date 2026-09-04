require "rails_helper"

RSpec.describe EventPlans::Suggest do
  it "persists bounded source-backed suggestions and preserves plan provenance" do
    plan = create(:event_plan)
    memory = create(:memory_record, relationship_profile: plan.relationship_profile)
    generator = double(generate: [
      {
        "phase" => "arrange",
        "kind" => "vendor_need",
        "title" => "Ask about a quiet table",
        "details" => "Confirm a low-noise seating option.",
        "due_on" => "2026-09-05",
        "source_ids" => [ "memory:#{memory.id}" ]
      }
    ])

    suggestions = described_class.call(actor: plan.user, event_plan: plan, generator:)

    expect(suggestions.sole).to have_attributes(
      origin: "ai",
      kind: "vendor_need",
      title: "Ask about a quiet table",
      due_on: Date.new(2026, 9, 5)
    )
    expect(suggestions.sole.source_context.sole).to include(
      "id" => "memory:#{memory.id}", "sensitive" => false
    )
    expect(plan.reload.source_context.map { |source| source["id"] }).to include("memory:#{memory.id}")
    expect(AuditEvent.where(user: plan.user, action: "event_plan.suggestions_generated", target: plan)).to exist
  end

  it "requires an active vault lease before reading selected protected context" do
    plan = create(:event_plan)
    vault_item = create(:privacy_vault_item, relationship_profile: plan.relationship_profile, suggestion_usage: "allowed")

    expect do
      described_class.call(
        actor: plan.user,
        event_plan: plan,
        vault_item_ids: [ vault_item.id ],
        generator: double
      )
    end.to raise_error(EventPlans::VaultAccessError)
  end

  it "rejects unknown evidence and unsupported planning fields" do
    plan = create(:event_plan)
    unknown_source = double(generate: [
      {
        "phase" => "arrange", "kind" => "task", "title" => "Invented",
        "details" => nil, "due_on" => nil, "source_ids" => [ "memory:unknown" ]
      }
    ])

    expect do
      described_class.call(actor: plan.user, event_plan: plan, generator: unknown_source)
    end.to raise_error(EventPlans::GenerationError, "Event plan suggestion cited an unknown source")

    unsupported = double(generate: [
      {
        "phase" => "buy_everything", "kind" => "purchase", "title" => "Act automatically",
        "details" => nil, "due_on" => nil, "source_ids" => [ "profile:#{plan.relationship_profile_id}" ]
      }
    ])
    expect do
      described_class.call(actor: plan.user, event_plan: plan, generator: unsupported)
    end.to raise_error(EventPlans::GenerationError, "Event plan suggestion response was invalid")
  end

  it "rejects output when plan context changes during provider generation" do
    plan = create(:event_plan)
    generator = double
    allow(generator).to receive(:generate) do
      plan.update!(notes: "The plan changed")
      [
        {
          "phase" => "decide", "kind" => "task", "title" => "Stale idea",
          "details" => nil, "due_on" => nil, "source_ids" => [ "profile:#{plan.relationship_profile_id}" ]
        }
      ]
    end

    expect do
      described_class.call(actor: plan.user, event_plan: plan, generator:)
    end.to raise_error(EventPlans::GenerationSupersededError)
  end

  it "sends the provider an immutable snapshot captured before generation" do
    plan = create(:event_plan, notes: "Original plan notes")
    task = create(:plan_task, event_plan: plan, title: "Original task title")
    captured_snapshot = nil
    generator = double
    allow(generator).to receive(:generate) do |plan_snapshot:, **|
      captured_snapshot = plan_snapshot
      plan.update!(notes: "Changed after consent")
      task.update!(title: "Changed after consent")
      []
    end

    expect do
      described_class.call(actor: plan.user, event_plan: plan, generator:)
    end.to raise_error(EventPlans::GenerationSupersededError)
    expect(captured_snapshot).to have_attributes(notes: "Original plan notes")
    expect(captured_snapshot.existing_tasks.sole).to have_attributes(title: "Original task title")
  end

  it "excludes superseded tasks from the provider snapshot" do
    plan = create(:event_plan)
    current_task = create(:plan_task, event_plan: plan, title: "Current task")
    superseded_task = create(:plan_task, event_plan: plan, title: "Old task", superseded_at: 1.hour.ago)
    booking = create(:booking, user: plan.user, event_plan: plan, title: "Private booking task")
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    captured_snapshot = nil
    generator = double
    allow(generator).to receive(:generate) do |plan_snapshot:, **|
      captured_snapshot = plan_snapshot
      []
    end

    expect do
      described_class.call(actor: plan.user, event_plan: plan, generator:)
    end.to raise_error(EventPlans::GenerationError, /no usable steps/)

    expect(captured_snapshot.existing_tasks.map(&:title)).to include(current_task.title)
    expect(captured_snapshot.existing_tasks.map(&:title)).not_to include(superseded_task.title)
    expect(captured_snapshot.existing_tasks.map(&:title)).not_to include(booking.plan_task.title)
  end

  it "rejects output when the relationship is archived during provider generation" do
    plan = create(:event_plan)
    generator = double
    allow(generator).to receive(:generate) do
      plan.relationship_profile.archive!
      [
        {
          "phase" => "decide", "kind" => "task", "title" => "Archived-context idea",
          "details" => nil, "due_on" => nil, "source_ids" => [ "profile:#{plan.relationship_profile_id}" ]
        }
      ]
    end

    expect do
      described_class.call(actor: plan.user, event_plan: plan, generator:)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(plan.plan_tasks.where(origin: "ai")).to be_empty
  end

  it "records metadata-only evidence when explicitly selected sensitive sources are used" do
    plan = create(:event_plan)
    private_note = create(:relationship_note, relationship_profile: plan.relationship_profile, private: true)
    generator = double(generate: [
      {
        "phase" => "decide", "kind" => "task", "title" => "Sensitive-context idea",
        "details" => nil, "due_on" => nil, "source_ids" => [ "private_note:#{private_note.id}" ]
      }
    ])

    described_class.call(
      actor: plan.user,
      event_plan: plan,
      private_note_ids: [ private_note.id ],
      generator:
    )

    event = AuditEvent.find_by!(user: plan.user, action: "sensitive_record.accessed", target: plan.relationship_profile)
    expect(event.metadata).to eq("result" => "event_plan_suggestion")
  end

  it "does not reuse a prior-plan-derived task after its sensitive context is no longer selected" do
    profile = create(:relationship_profile)
    private_note = create(:relationship_note, relationship_profile: profile, private: true)
    prior_plan = create(
      :event_plan,
      user: profile.user,
      relationship_profile: profile,
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
          "label" => "Prior anniversary plan",
          "role" => "prior_anniversary_context",
          "certainty" => "needs_confirmation"
        }
      ]
    )
    first_generator = double
    allow(first_generator).to receive(:generate) do |sources:, **|
      prior_source = sources.find { |source| source.kind == "prior_anniversary_plan" }
      [
        {
          "phase" => "decide",
          "kind" => "task",
          "title" => "Sensitive prior-plan suggestion",
          "details" => nil,
          "due_on" => nil,
          "source_ids" => [ prior_source.id ]
        }
      ]
    end
    described_class.call(
      actor: plan.user,
      event_plan: plan,
      private_note_ids: [ private_note.id ],
      generator: first_generator
    )

    captured_snapshot = nil
    second_generator = double
    allow(second_generator).to receive(:generate) do |plan_snapshot:, **|
      captured_snapshot = plan_snapshot
      [
        {
          "phase" => "decide",
          "kind" => "task",
          "title" => "Current-context suggestion",
          "details" => nil,
          "due_on" => nil,
          "source_ids" => [ "profile:#{profile.id}" ]
        }
      ]
    end

    described_class.call(actor: plan.user, event_plan: plan, generator: second_generator)

    expect(captured_snapshot.existing_tasks.map(&:title)).not_to include("Sensitive prior-plan suggestion")
  end
end
