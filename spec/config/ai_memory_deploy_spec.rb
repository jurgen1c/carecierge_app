require "rails_helper"

RSpec.describe "AI deployment configuration" do
  it "injects the OpenAI key and configurable models through Kamal without storing secret values" do
    deploy_config = YAML.safe_load(Rails.root.join("config/deploy.yml").read)
    secrets = Rails.root.join(".kamal/secrets").read

    expect(deploy_config.dig("env", "secret")).to include("OPENAI_API_KEY")
    expect(deploy_config.dig("env", "clear")).to include(
      "CARECIERGE_MEMORY_EXTRACTION_MODEL",
      "CARECIERGE_MESSAGE_DRAFTING_MODEL",
      "CARECIERGE_RELATIONSHIP_BRIEFING_MODEL",
      "CARECIERGE_SOCIAL_CONTEXT_MODEL"
    )
    expect(secrets).to include("OPENAI_API_KEY=$OPENAI_API_KEY")
  end
end
