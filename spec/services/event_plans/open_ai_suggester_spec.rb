require "rails_helper"

RSpec.describe EventPlans::OpenAiSuggester do
  it "requests non-stored structured, review-only planning suggestions" do
    plan = create(:event_plan)
    source = EventPlans::ContextBuilder::Source.new(
      id: "memory:123",
      kind: "memory",
      content: "Prefers quiet dinners",
      certainty: "confirmed",
      label: "Relationship memory",
      sensitive: false
    )
    authorized_private_source = EventPlans::ContextBuilder::Source.new(
      id: "private_note:allowed",
      kind: "private_note",
      content: "Keep the dinner discreet",
      certainty: "confirmed",
      label: "Private note",
      sensitive: true
    )
    create(:plan_task, event_plan: plan, title: "Public existing step")
    create(
      :plan_task,
      event_plan: plan,
      title: "Authorized private step",
      source_context: [
        { "id" => authorized_private_source.id, "label" => "Private note", "certainty" => "confirmed", "sensitive" => true }
      ]
    )
    create(
      :plan_task,
      event_plan: plan,
      title: "Expired vault step",
      source_context: [
        { "id" => "vault:expired", "label" => "Privacy vault", "certainty" => "confirmed", "sensitive" => true }
      ]
    )
    create(
      :plan_task,
      event_plan: plan,
      title: "Revoked public-source step",
      source_context: [
        { "id" => "memory:revoked", "label" => "Relationship memory", "certainty" => "confirmed", "sensitive" => false }
      ]
    )
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, JSON.generate(
      status: "completed",
      output: [
        {
          type: "message",
          content: [
            {
              type: "output_text",
              text: JSON.generate(suggestions: [
                {
                  phase: "arrange",
                  kind: "vendor_need",
                  title: "Ask about a quiet table",
                  details: "Confirm a low-noise seating option.",
                  due_on: "2026-09-05",
                  source_ids: [ "memory:123" ]
                }
              ])
            }
          ]
        }
      ]
    ))
    response.instance_variable_set(:@read, true)
    request = nil

    plan_snapshot = EventPlans::Suggest::PlanSnapshot.new(
      title: plan.title,
      occasion_type: plan.occasion_type,
      starts_on: plan.starts_on,
      budget_cents: plan.budget_cents,
      guest_list: plan.guest_list,
      notes: plan.notes,
      existing_tasks: plan.plan_tasks.ordered.select do |task|
        task.title.in?([ "Public existing step", "Authorized private step" ])
      end.map do |task|
        EventPlans::Suggest::TaskSnapshot.new(
          phase: task.phase,
          kind: task.kind,
          title: task.title,
          details: task.details,
          due_on: task.due_on,
          completed: task.completed?
        )
      end
    )
    result = described_class.new(
      api_key: "test-key",
      model: "test-model",
      transport: ->(outbound) { request = outbound; response }
    ).generate(plan_snapshot:, sources: [ source, authorized_private_source ], locale: :en)

    payload = JSON.parse(request.body)
    input = JSON.parse(payload.fetch("input"))
    expect(payload).to include("model" => "test-model", "store" => false)
    expect(payload.dig("text", "format", "type")).to eq("json_schema")
    expect(input.fetch("event_plan")).to include("occasion_type" => "birthday", "budget_cents" => 15_000)
    expect(input.dig("event_plan", "existing_tasks").pluck("title")).to contain_exactly(
      "Public existing step",
      "Authorized private step"
    )
    expect(payload.fetch("instructions")).to include("untrusted", "Never send", "contact vendors", "purchase")
    expect(result.sole.fetch("title")).to eq("Ask about a quiet table")
  end

  it "fails before a request when credentials are absent" do
    plan_snapshot = EventPlans::Suggest::PlanSnapshot.new(
      title: "Plan",
      occasion_type: "custom",
      starts_on: nil,
      budget_cents: nil,
      guest_list: nil,
      notes: nil,
      existing_tasks: []
    )
    expect do
      described_class.new(api_key: "").generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event planning suggestions are not configured")
  end

  it "rejects failed, incomplete, and malformed provider responses" do
    plan_snapshot = EventPlans::Suggest::PlanSnapshot.new(
      title: "Plan",
      occasion_type: "custom",
      starts_on: nil,
      budget_cents: nil,
      guest_list: nil,
      notes: nil,
      existing_tasks: []
    )
    failed = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
    failed.instance_variable_set(:@read, true)
    incomplete = Net::HTTPOK.new("1.1", "200", "OK")
    incomplete.instance_variable_set(:@body, JSON.generate(status: "incomplete"))
    incomplete.instance_variable_set(:@read, true)
    malformed = Net::HTTPOK.new("1.1", "200", "OK")
    malformed.instance_variable_set(:@body, JSON.generate(
      status: "completed",
      output: [
        {
          type: "message",
          content: [ { type: "output_text", text: JSON.generate(suggestions: "not-an-array") } ]
        }
      ]
    ))
    malformed.instance_variable_set(:@read, true)
    scalar = Net::HTTPOK.new("1.1", "200", "OK")
    scalar.instance_variable_set(:@body, JSON.generate(
      status: "completed",
      output: [
        {
          type: "message",
          content: [ { type: "output_text", text: "null" } ]
        }
      ]
    ))
    scalar.instance_variable_set(:@read, true)

    expect do
      described_class.new(api_key: "key", transport: ->(_) { failed }).generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event planning suggestion request failed")
    expect do
      described_class.new(api_key: "key", transport: ->(_) { incomplete }).generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event planning suggestion response was incomplete")
    expect do
      described_class.new(api_key: "key", transport: ->(_) { malformed }).generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event plan suggestion response was invalid")
    expect do
      described_class.new(api_key: "key", transport: ->(_) { scalar }).generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event plan suggestion response was invalid")
  end
end
