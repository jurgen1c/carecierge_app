require "rails_helper"

RSpec.describe BackupPlans::OpenAiGenerator do
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

  it "requests non-stored, structured, review-only backup options" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, JSON.generate(
      status: "completed",
      output: [
        {
          type: "message",
          content: [
            {
              type: "output_text",
              text: JSON.generate(options: [
                {
                  title: "Move indoors",
                  summary: "Keep the same people and date.",
                  effort: "low",
                  timing: "same_day",
                  estimated_cost_cents: 15_000,
                  cost_level: "similar",
                  relationship_fit: "strong",
                  preserved_constraints: [ "Quiet setting" ],
                  change_summary: [ "Venue" ],
                  replacement_task_ids: [ task.id ],
                  source_ids: [ source.id ],
                  tasks: [
                    {
                      phase: "arrange",
                      kind: "backup_step",
                      title: "Confirm indoor venue",
                      details: nil,
                      due_on: nil,
                      source_ids: [ source.id ]
                    }
                  ]
                }
              ])
            }
          ]
        }
      ]
    ))
    response.instance_variable_set(:@read, true)
    request = nil

    result = described_class.new(
      api_key: "test-key",
      model: "test-model",
      transport: ->(outbound) { request = outbound; response }
    ).generate(plan_snapshot:, scenario: "weather", sources: [ source ], locale: :en, count: 3)

    payload = JSON.parse(request.body)
    input = JSON.parse(payload.fetch("input"))
    expect(payload).to include("model" => "test-model", "store" => false)
    expect(payload.dig("text", "format", "type")).to eq("json_schema")
    expect(input).to include("scenario" => "weather")
    expect(input.dig("event_plan", "existing_tasks").sole).to include("id" => task.id, "completed" => false)
    expect(payload.fetch("instructions")).to include("untrusted", "never replace completed work", "explicitly")
    expect(result.sole.fetch("title")).to eq("Move indoors")
  end

  it "fails before a request when credentials are absent" do
    expect do
      described_class.new(api_key: "").generate(
        plan_snapshot:,
        scenario: "weather",
        sources: [ source ],
        locale: :en
      )
    end.to raise_error(EventPlans::GenerationError, "Backup plan generation is not configured")
  end
end
