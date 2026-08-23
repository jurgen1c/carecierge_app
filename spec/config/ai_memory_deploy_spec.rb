require "rails_helper"
require "erb"

RSpec.describe "AI deployment configuration" do
  it "injects selectable provider keys and configurable models through Kamal without storing secret values" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CARECIERGE_EVENT_PLAN_MODEL").and_return(nil)
    deploy_config = YAML.safe_load(ERB.new(Rails.root.join("config/deploy.yml").read).result)
    secrets = Rails.root.join(".kamal/secrets").read

    expect(deploy_config.dig("env", "secret")).to include(
      "OPENAI_API_KEY",
      "ANTHROPIC_API_KEY",
      "GEMINI_API_KEY"
    )
    expect(deploy_config.dig("env", "clear")).to include(
      "CARECIERGE_MEMORY_EXTRACTION_MODEL",
      "CARECIERGE_MESSAGE_DRAFTING_MODEL",
      "CARECIERGE_RELATIONSHIP_BRIEFING_MODEL",
      "CARECIERGE_SOCIAL_CONTEXT_MODEL",
      "CARECIERGE_EVENT_PLAN_PROVIDER"
    )
    expect(deploy_config.dig("env", "clear")).not_to include("CARECIERGE_EVENT_PLAN_MODEL")
    expect(secrets).to include(
      "OPENAI_API_KEY=$OPENAI_API_KEY",
      "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY",
      "GEMINI_API_KEY=$GEMINI_API_KEY"
    )
  end

  it "injects an explicitly configured event-plan model" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("CARECIERGE_EVENT_PLAN_MODEL").and_return("claude-haiku-4-5")

    deploy_config = YAML.safe_load(ERB.new(Rails.root.join("config/deploy.yml").read).result)

    expect(deploy_config.dig("env", "clear", "CARECIERGE_EVENT_PLAN_MODEL")).to eq("claude-haiku-4-5")
  end
end
