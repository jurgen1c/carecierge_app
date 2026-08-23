require "rails_helper"

RSpec.describe EventPlans::LlmConfiguration do
  it "normalizes configured and explicit provider values" do
    credentials = Rails.application.credentials
    allow(credentials).to receive(:dig).and_call_original
    allow(credentials).to receive(:dig).with(:event_plans, :provider).and_return(nil)
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch)
      .with("CARECIERGE_EVENT_PLAN_PROVIDER", described_class::DEFAULT_PROVIDER)
      .and_return(" OpenAI ")

    expect(described_class.provider).to eq("openai")
    expect(described_class.chat_options(model: "claude-current", provider: " Anthropic ")).to include(
      model: "claude-current",
      provider: :anthropic
    )
    expect(described_class.response_params(provider: " OpenAI ", output_token_limit: 123)).to eq(
      store: false,
      max_completion_tokens: 123
    )
  end
end
