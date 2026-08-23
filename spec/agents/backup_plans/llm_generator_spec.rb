require "rails_helper"

RSpec.describe BackupPlans::LlmGenerator do
  let(:plan) { create(:event_plan) }
  let(:task) { create(:plan_task, event_plan: plan, title: "Confirm outdoor venue") }
  let(:source) do
    EventPlans::ContextBuilder::Source.new(
      id: "preference:123",
      kind: "constraint",
      content: "Avoid loud spaces",
      certainty: "confirmed",
      label: "Constraint",
      sensitive: false
    )
  end
  let(:plan_snapshot) do
    BackupPlans::Generate::PlanSnapshot.new(
      title: plan.title,
      occasion_type: plan.occasion_type,
      starts_on: plan.starts_on,
      budget_cents: plan.budget_cents,
      guest_list: plan.guest_list,
      notes: plan.notes,
      existing_tasks: [
        BackupPlans::Generate::TaskSnapshot.new(
          id: task.id,
          phase: task.phase,
          kind: task.kind,
          title: task.title,
          details: task.details,
          due_on: task.due_on,
          completed: false
        )
      ]
    )
  end

  it "uses RubyLLM structured output for provider-neutral backup options" do
    chat = double("RubyLLM chat")
    response = double(content: {
      "options" => [
        {
          "title" => "Move indoors",
          "summary" => "Keep the same people and date.",
          "effort" => "low",
          "timing" => "same_day",
          "estimated_cost_cents" => 15_000,
          "cost_level" => "similar",
          "relationship_fit" => "strong",
          "preserved_constraints" => [ "Quiet setting" ],
          "change_summary" => [ "Venue" ],
          "replacement_task_ids" => [ task.id ],
          "source_ids" => [ source.id ],
          "tasks" => [
            {
              "phase" => "arrange",
              "kind" => "backup_step",
              "title" => "Confirm indoor venue",
              "details" => nil,
              "due_on" => nil,
              "source_ids" => [ source.id ]
            }
          ]
        }
      ]
    })
    input = nil

    expect(RubyLLM).to receive(:chat)
      .with(model: "gemini-2.5-flash", provider: :gemini, assume_model_exists: true)
      .and_return(chat)
    expect(chat).to receive(:with_instructions).with(include("untrusted", "never replace completed work", "explicitly")).and_return(chat)
    expect(chat).to receive(:with_schema).with(hash_including(name: "event_plan_backup_options", schema: described_class::SCHEMA)).and_return(chat)
    expect(chat).to receive(:with_params)
      .with(generationConfig: { maxOutputTokens: 4_000 })
      .and_return(chat)
    expect(chat).to receive(:ask) { |payload| input = JSON.parse(payload); response }

    result = described_class.new(model: "gemini-2.5-flash", provider: "gemini")
      .generate(plan_snapshot:, scenario: "weather", sources: [ source ], locale: :en, count: 3)

    expect(input).to include("scenario" => "weather")
    expect(input.dig("event_plan", "existing_tasks").sole).to include("id" => task.id, "completed" => false)
    expect(result.sole.fetch("title")).to eq("Move indoors")
  end

  it "chooses a compatible default model for an explicitly selected provider" do
    chat = double("RubyLLM chat")
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask).and_return(double(content: { "options" => [] }))

    expect(RubyLLM).to receive(:chat)
      .with(model: "gemini-2.5-flash", provider: :gemini)
      .and_return(chat)

    described_class.new(provider: "gemini")
      .generate(plan_snapshot:, scenario: "weather", sources: [ source ], locale: :en)
  end

  it "maps provider configuration failures to the event planning boundary" do
    allow(RubyLLM).to receive(:chat).and_raise(RubyLLM::ConfigurationError, "missing key")

    expect do
      described_class.new.generate(plan_snapshot:, scenario: "weather", sources: [ source ], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Backup plan provider was unavailable")
  end

  it "maps exhausted provider transport failures to the event planning boundary" do
    allow(RubyLLM).to receive(:chat).and_raise(Faraday::ParsingError, "malformed response")

    expect do
      described_class.new.generate(plan_snapshot:, scenario: "weather", sources: [ source ], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Backup plan provider was unavailable")
  end

  it "maps an incomplete successful provider response to the event planning boundary" do
    chat = double("RubyLLM chat")
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask) { nil.content }
    allow(RubyLLM).to receive(:chat).and_return(chat)

    expect do
      described_class.new.generate(plan_snapshot:, scenario: "weather", sources: [ source ], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Backup plan response was invalid")
  end
end
