require "rails_helper"

RSpec.describe GiftRecommendations::OpenAiGenerator do
  it "requests non-stored structured ideas with untrusted source input and repeat controls" do
    source = GiftRecommendations::ContextBuilder::Source.new(
      id: "preference:123",
      kind: "preference",
      content: "Coffee: light roasts",
      certainty: "confirmed",
      label: "Preference",
      sensitive: false
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
              text: JSON.generate(
                recommendations: [
                  {
                    title: "Light-roast tasting set",
                    rationale: "It matches the confirmed coffee preference.",
                    source_ids: [ "preference:123" ],
                    estimated_price_cents: 4_000,
                    vendor: nil
                  }
                ]
              )
            }
          ]
        }
      ]
    ))
    response.instance_variable_set(:@read, true)
    request = nil

    result = described_class.new(api_key: "test-key", model: "test-model", transport: ->(outbound) { request = outbound; response }).generate(
      sources: [ source ],
      budget_cents: 5_000,
      needed_by: Date.new(2026, 9, 1),
      occasion: "Birthday",
      allow_repeats: false,
      excluded_titles: [ "Ceramic mug" ],
      locale: :en
    )

    payload = JSON.parse(request.body)
    input = JSON.parse(payload.fetch("input"))
    expect(payload).to include("model" => "test-model", "store" => false)
    expect(payload.dig("text", "format", "type")).to eq("json_schema")
    expect(input).to include(
      "budget_cents" => 5_000,
      "allow_repeats" => false,
      "excluded_titles" => [ "Ceramic mug" ]
    )
    expect(input.fetch("sources").sole).to include("id" => "preference:123")
    expect(payload.fetch("instructions")).to include("untrusted", "purchase anything")
    expect(result.sole.fetch("title")).to eq("Light-roast tasting set")
  end

  it "fails before a request when credentials are absent" do
    expect do
      described_class.new(api_key: "").generate(
        sources: [], budget_cents: nil, needed_by: nil, occasion: nil,
        allow_repeats: false, excluded_titles: [], locale: :en
      )
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendations are not configured")
  end
end
