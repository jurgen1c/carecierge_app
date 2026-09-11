require "rails_helper"

RSpec.describe "Environment-based AI providers" do
  before do
    allow(Rails.application.credentials).to receive(:dig).and_return(nil)
    allow(ENV).to receive(:[]).and_call_original
    %w[CARECIERGE_AI_PROVIDER CARECIERGE_AI_MODEL CARECIERGE_OLLAMA_MODEL CARECIERGE_EVENT_PLAN_MODEL].each do |key|
      allow(ENV).to receive(:[]).with(key).and_return(nil)
    end
  end

  it "defaults development to a small local model without cloud credentials" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))

    expect(Ai::Configuration.provider).to eq("ollama")
    expect(EventPlans::LlmConfiguration.provider).to eq("ollama")
    expect(EventPlans::LlmConfiguration.chat_options).to eq(
      provider: :ollama, model: "carecierge-dev", assume_model_exists: true)
    expect(MessageDrafts::OpenAiGenerator.default_model).to eq("carecierge-dev")
    expect(Ai::Configuration.request_timeout(provider: "ollama")).to eq(90)
  end

  it "defaults production and deterministic tests to OpenAI" do
    %w[production test].each do |environment|
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new(environment))

      expect(Ai::Configuration.provider).to eq("openai")
      expect(EventPlans::LlmConfiguration.chat_options).to include(provider: :openai, model: "gpt-5-mini")
    end
  end

  it "honors an operator's provider and model overrides" do
    allow(ENV).to receive(:[]).with("CARECIERGE_AI_PROVIDER").and_return(" Ollama ")
    allow(ENV).to receive(:[]).with("CARECIERGE_AI_MODEL").and_return("carecierge-local")

    expect(EventPlans::LlmConfiguration.chat_options).to eq(
      provider: :ollama, model: "carecierge-local", assume_model_exists: true)
    expect(RelationshipBriefings::OpenAiGenerator.default_model).to eq("carecierge-local")
  end

  it "keeps provider-specific model defaults separate" do
    allow(ENV).to receive(:[]).with("CARECIERGE_AI_MODEL").and_return("gpt-next")

    expect(Ai::Configuration.model(provider: "ollama")).to eq("carecierge-dev")
    expect(EventPlans::LlmConfiguration.response_params(provider: "ollama", output_token_limit: 123)).to eq(
      max_tokens: 123, reasoning_effort: "none")
  end
end
