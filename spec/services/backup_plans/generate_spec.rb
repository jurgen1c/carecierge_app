require "rails_helper"

RSpec.describe BackupPlans::Generate do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:event_plan) { create(:event_plan, user:, relationship_profile: profile) }
  let!(:replaceable_task) { create(:plan_task, event_plan:, title: "Confirm outdoor venue") }
  let(:source_id) { "profile:#{profile.id}" }
  let(:raw_options) do
    3.times.map do |position|
      {
        "title" => "Backup option #{position + 1}",
        "summary" => "A calm alternative that keeps the important details.",
        "effort" => %w[low medium high].fetch(position),
        "timing" => %w[same_day within_week new_date].fetch(position),
        "estimated_cost_cents" => 14_000 + position * 1_000,
        "cost_level" => %w[similar higher higher].fetch(position),
        "relationship_fit" => %w[strong good fair].fetch(position),
        "preserved_constraints" => [ "Budget", "Guest list" ],
        "change_summary" => [ "Venue" ],
        "replacement_task_ids" => position.zero? ? [ replaceable_task.id ] : [],
        "source_ids" => [ source_id ],
        "tasks" => [
          {
            "phase" => "arrange",
            "kind" => "backup_step",
            "title" => "Confirm backup venue #{position + 1}",
            "details" => "Review availability before committing.",
            "due_on" => "2026-09-10",
            "source_ids" => [ source_id ]
          }
        ]
      }
    end
  end
  let(:generator) { instance_double(BackupPlans::LlmGenerator, generate: raw_options) }

  it "persists three comparable source-backed options without changing active tasks" do
    reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      event_plan:,
      plan_task: replaceable_task,
      title: "Confirm the outdoor venue reminder"
    )

    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to change(BackupPlan, :count).by(1).and change(BackupOption, :count).by(3)
      .and change(PlanTask, :count).by(0)

    backup_plan = event_plan.backup_plans.last
    expect(backup_plan).to have_attributes(
      user:,
      scenario: "weather",
      status: "generated",
      locale: "en",
      event_plan_generation_version: event_plan.reload.generation_version
    )
    expect(backup_plan.context_fingerprint).to match(/\A[0-9a-f]{64}\z/)
    expect(backup_plan.backup_options.ordered.map(&:effort)).to eq(%w[low medium high])
    expect(backup_plan.backup_options.first.task_blueprints.first).to include(
      "title" => "Confirm backup venue 1",
      "source_context" => [ hash_including("id" => source_id) ]
    )
    expect(backup_plan.backup_options.first.reviewed_reminders).to contain_exactly(
      hash_including(
        "id" => reminder.id,
        "plan_task_id" => replaceable_task.id,
        "title" => "Confirm the outdoor venue reminder"
      )
    )
    expect(generator).to have_received(:generate).with(hash_including(
      scenario: "weather",
      count: 3,
      sources: include(have_attributes(id: source_id))
    ))
  end

  it "excludes prior AI tasks whose sources were not authorized for this request" do
    private_note = create(:relationship_note, relationship_profile: profile, private: true)
    sensitive_task = create(
      :plan_task,
      event_plan:,
      origin: "ai",
      title: "Sensitive prior suggestion",
      source_context: [
        {
          "id" => "private_note:#{private_note.id}",
          "label" => "Private note",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    captured_snapshot = nil
    allow(generator).to receive(:generate) do |plan_snapshot:, **|
      captured_snapshot = plan_snapshot
      raw_options
    end

    described_class.call(actor: user, event_plan:, scenario: "weather", generator:)

    expect(captured_snapshot.existing_tasks.map(&:id)).to include(replaceable_task.id)
    expect(captured_snapshot.existing_tasks.map(&:id)).not_to include(sensitive_task.id)
  end

  it "rejects output that cites an unknown source" do
    raw_options.first["source_ids"] = [ "preference:missing" ]

    count = BackupPlan.count
    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to raise_error(EventPlans::GenerationError, /unknown source/)
    expect(BackupPlan.count).to eq(count)
  end

  it "rejects a provider response without usable options" do
    allow(generator).to receive(:generate).and_return([])

    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to raise_error(EventPlans::GenerationError, "Backup plan response had no usable options")
  end

  it "rejects repeated option titles" do
    raw_options.second["title"] = raw_options.first.fetch("title")

    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to raise_error(EventPlans::GenerationError, "Backup plan response repeated an option")
  end

  it "rejects invalid estimated costs" do
    raw_options.first["estimated_cost_cents"] = -1

    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to raise_error(EventPlans::GenerationError, "Backup plan response was invalid")
  end

  it "rejects an excessive replacement set" do
    raw_options.first["replacement_task_ids"] = 9.times.map { |index| "task-#{index}" }

    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to raise_error(EventPlans::GenerationError, "Backup plan response tried to replace an unavailable task")
  end

  it "rejects output when the plan changes during generation" do
    allow(generator).to receive(:generate) do |**|
      EventPlans::Update.call(event_plan:, attributes: { notes: "The plan changed." })
      raw_options
    end

    count = BackupPlan.count
    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", generator:)
    end.to raise_error(EventPlans::GenerationSupersededError)
    expect(BackupPlan.count).to eq(count)
  end

  it "fails closed for another user's plan" do
    expect do
      described_class.call(actor: create(:user), event_plan:, scenario: "weather", generator:)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects unsupported scenarios before calling the provider" do
    expect do
      described_class.call(actor: user, event_plan:, scenario: "surprise_dragon", generator:)
    end.to raise_error(EventPlans::GenerationError, "Backup plan scenario was invalid")
    expect(generator).not_to have_received(:generate)
  end

  it "rejects unsupported locales before calling the provider" do
    expect do
      described_class.call(actor: user, event_plan:, scenario: "weather", locale: :fr, generator:)
    end.to raise_error(EventPlans::GenerationError, "Backup plan locale was invalid")
    expect(generator).not_to have_received(:generate)
  end

  it "rejects selected vault items that are no longer allowed for suggestions" do
    vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "excluded")

    expect do
      described_class.call(
        actor: user,
        event_plan:,
        scenario: "weather",
        vault_item_ids: [ vault_item.id ],
        vault_lease: PrivacyVault::Lease.issue_for(user),
        generator:
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(generator).not_to have_received(:generate)
  end
end
