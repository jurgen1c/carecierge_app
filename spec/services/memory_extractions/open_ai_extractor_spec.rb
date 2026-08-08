require "rails_helper"

RSpec.describe MemoryExtractions::OpenAiExtractor do
  it "requests a non-stored structured response and returns proposals" do
    recap = create(:conversation_recap, body: "She said jasmine tea helps her relax.")
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, JSON.generate(
      output: [
        {
          type: "message",
          content: [
            {
              type: "output_text",
              text: JSON.generate(
                memories: [
                  {
                    category: "preference",
                    title: "Likes jasmine tea",
                    body: "Jasmine tea helps her relax.",
                    source_excerpt: "jasmine tea helps her relax",
                    confidence: "high"
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
    transport = lambda do |outbound_request|
      request = outbound_request
      response
    end

    proposals = described_class.new(api_key: "test-key", model: "test-model", transport:).extract(recap)

    payload = JSON.parse(request.body)
    expect(payload).to include("model" => "test-model", "store" => false)
    expect(payload.dig("text", "format", "type")).to eq("json_schema")
    expect(payload.fetch("input")).to include("jasmine tea")
    expect(proposals.sole).to include("category" => "preference", "confidence" => "high")
  end

  it "fails before a request when credentials are absent" do
    recap = build(:conversation_recap)

    expect { described_class.new(api_key: "").extract(recap) }
      .to raise_error(MemoryExtractions::ExtractionError, "AI extraction is not configured")
  end
end
