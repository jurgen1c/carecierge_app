require "rails_helper"

RSpec.describe EventPlans::LlmSuggester do
  let(:plan) { create(:event_plan) }
  let(:source) do
    EventPlans::ContextBuilder::Source.new(
      id: "memory:123",
      kind: "memory",
      content: "Prefers quiet dinners",
      certainty: "confirmed",
      label: "Relationship memory",
      sensitive: false
    )
  end
  let(:plan_snapshot) do
    EventPlans::Suggest::PlanSnapshot.new(
      title: plan.title,
      occasion_type: plan.occasion_type,
      tone: "understated",
      effort_level: "low",
      starts_on: plan.starts_on,
      budget_cents: plan.budget_cents,
      guest_list: plan.guest_list,
      notes: plan.notes,
      existing_tasks: []
    )
  end

  it "uses RubyLLM structured output with a swappable provider" do
    chat = double("RubyLLM chat")
    response = double(content: {
      "suggestions" => [
        {
          "phase" => "arrange",
          "kind" => "vendor_need",
          "title" => "Ask about a quiet table",
          "details" => "Confirm a low-noise seating option.",
          "due_on" => "2026-09-05",
          "source_ids" => [ "memory:123" ]
        }
      ]
    })
    input = nil

    expect(RubyLLM).to receive(:chat)
      .with(model: "claude-haiku-4-5", provider: :anthropic, assume_model_exists: true)
      .and_return(chat)
    expect(chat).to receive(:with_instructions).with(include("untrusted", "Never send", "purchase", "cheesy", "surveillance")).and_return(chat)
    expect(chat).to receive(:with_schema).with(hash_including(name: "event_plan_suggestions", schema: described_class::SCHEMA)).and_return(chat)
    expect(chat).to receive(:with_params).with(max_tokens: 2_000).and_return(chat)
    expect(chat).to receive(:ask) { |payload| input = JSON.parse(payload); response }

    result = described_class.new(model: "claude-haiku-4-5", provider: "anthropic")
      .generate(plan_snapshot:, sources: [ source ], locale: :en)

    expect(input.fetch("event_plan")).to include(
      "occasion_type" => "birthday",
      "tone" => "understated",
      "budget_cents" => 15_000
    )
    expect(input.fetch("event_plan")).not_to have_key("effort_level")
    expect(input.fetch("sources").sole).to include("id" => "memory:123")
    expect(result.sole.fetch("title")).to eq("Ask about a quiet table")
  end

  it "supplies the visible effort preference for anniversary suggestions" do
    chat = double("RubyLLM chat")
    input = nil
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask) do |payload|
      input = JSON.parse(payload)
      double(content: { "suggestions" => [] })
    end
    allow(RubyLLM).to receive(:chat).and_return(chat)

    anniversary_snapshot = EventPlans::Suggest::PlanSnapshot.new(
      **plan_snapshot.to_h.merge(occasion_type: "anniversary", effort_level: "low")
    )

    described_class.new.generate(plan_snapshot: anniversary_snapshot, sources: [ source ], locale: :en)

    expect(input.fetch("event_plan")).to include("occasion_type" => "anniversary", "effort_level" => "low")
  end

  it "disables OpenAI response storage without coupling other providers to that option" do
    chat = double("RubyLLM chat")
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    expect(chat).to receive(:with_params).with(store: false, max_completion_tokens: 2_000).and_return(chat)
    allow(chat).to receive(:ask).and_return(double(content: { "suggestions" => [] }))
    allow(RubyLLM).to receive(:chat)
      .with(model: "gpt-5-mini", provider: :openai, assume_model_exists: true)
      .and_return(chat)

    described_class.new(model: "gpt-5-mini", provider: "openai")
      .generate(plan_snapshot:, sources: [ source ], locale: :en)
  end

  it "chooses a compatible default model for an explicitly selected provider" do
    chat = double("RubyLLM chat")
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask).and_return(double(content: { "suggestions" => [] }))

    expect(RubyLLM).to receive(:chat)
      .with(model: "claude-haiku-4-5", provider: :anthropic)
      .and_return(chat)

    described_class.new(provider: "anthropic")
      .generate(plan_snapshot:, sources: [ source ], locale: :en)
  end

  it "prefers an explicit provider-neutral model over the legacy OpenAI credential" do
    credentials = Rails.application.credentials
    allow(credentials).to receive(:dig).and_call_original
    allow(credentials).to receive(:dig).with(:event_plans, :model).and_return(nil)
    allow(credentials).to receive(:dig).with(:openai, :event_plan_model).and_return("legacy-openai-model")
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CARECIERGE_EVENT_PLAN_MODEL").and_return("configured-openai-model")

    expect(described_class.default_model(provider: "openai")).to eq("configured-openai-model")
  end

  it "allows an explicitly configured model that is newer than RubyLLM's bundled registry" do
    credentials = Rails.application.credentials
    allow(credentials).to receive(:dig).and_call_original
    allow(credentials).to receive(:dig).with(:event_plans, :model).and_return(nil)
    allow(credentials).to receive(:dig).with(:openai, :event_plan_model).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CARECIERGE_EVENT_PLAN_MODEL").and_return("gpt-next-mini")
    chat = double("RubyLLM chat")
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask).and_return(double(content: { "suggestions" => [] }))

    expect(RubyLLM).to receive(:chat)
      .with(model: "gpt-next-mini", provider: :openai, assume_model_exists: true)
      .and_return(chat)

    described_class.new(provider: "openai")
      .generate(plan_snapshot:, sources: [ source ], locale: :en)
  end

  it "maps provider and configuration failures to the planning boundary" do
    allow(RubyLLM).to receive(:chat).and_raise(RubyLLM::ConfigurationError, "missing key")

    expect do
      described_class.new.generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event planning provider was unavailable")
  end

  it "maps exhausted provider transport failures to the planning boundary" do
    allow(RubyLLM).to receive(:chat).and_raise(Faraday::SSLError, "TLS failure")

    expect do
      described_class.new.generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event planning provider was unavailable")
  end

  it "maps an incomplete successful provider response to the planning boundary" do
    chat = double("RubyLLM chat")
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask) { nil.content }
    allow(RubyLLM).to receive(:chat).and_return(chat)

    expect do
      described_class.new.generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event plan suggestion response was invalid")
  end

  it "rejects malformed structured content returned by the provider" do
    chat = double("RubyLLM chat", with_instructions: nil)
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:with_schema).and_return(chat)
    allow(chat).to receive(:with_params).and_return(chat)
    allow(chat).to receive(:ask).and_return(double(content: { "suggestions" => "not-an-array" }))
    allow(RubyLLM).to receive(:chat).and_return(chat)

    expect do
      described_class.new.generate(plan_snapshot:, sources: [], locale: :en)
    end.to raise_error(EventPlans::GenerationError, "Event plan suggestion response was invalid")
  end
end
