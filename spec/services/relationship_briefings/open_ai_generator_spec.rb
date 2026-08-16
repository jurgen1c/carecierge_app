require "rails_helper"

RSpec.describe RelationshipBriefings::OpenAiGenerator do
  it "requests a non-stored structured briefing and returns source-backed sections" do
    source = RelationshipBriefings::ContextBuilder::Source.new(
      id: "timeline:123",
      kind: "timeline",
      section: "recent_activity",
      content: "Started a new role",
      certainty: "confirmed",
      label: "Timeline entry from August 14",
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
                sections: [
                  {
                    key: "recent_activity",
                    items: [
                      {
                        body: "Maya started a new role.",
                        certainty: "confirmed",
                        source_ids: [ "timeline:123" ]
                      }
                    ]
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

    sections = described_class.new(api_key: "test-key", model: "test-model", transport:).generate(
      interaction_context: "Dinner after work",
      sources: [ source ],
      locale: :en
    )

    payload = JSON.parse(request.body)
    untrusted_input = JSON.parse(payload.fetch("input"))
    expect(payload).to include("model" => "test-model", "store" => false)
    expect(payload.dig("text", "format", "type")).to eq("json_schema")
    expect(payload.dig("text", "format", "schema", "properties", "sections", "items", "properties", "items", "items", "properties", "source_ids")).not_to have_key("uniqueItems")
    expect(untrusted_input).to include("interaction_context" => "Dinner after work")
    expect(untrusted_input.fetch("sources").sole).to include("id" => "timeline:123")
    expect(payload.fetch("instructions")).to include("untrusted")
    expect(sections.dig(0, "items", 0)).to include(
      "certainty" => "confirmed",
      "source_ids" => [ "timeline:123" ]
    )
  end

  it "fails before a request when credentials are absent" do
    expect do
      described_class.new(api_key: "").generate(interaction_context: "Dinner", sources: [], locale: :en)
    end.to raise_error(RelationshipBriefings::GenerationError, "Relationship briefings are not configured")
  end

  it "rejects an incomplete provider response" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, JSON.generate(status: "in_progress", output: []))
    response.instance_variable_set(:@read, true)

    expect do
      described_class.new(api_key: "test", transport: ->(_) { response }).generate(
        interaction_context: "Dinner",
        sources: [],
        locale: :en
      )
    end.to raise_error(RelationshipBriefings::GenerationError, "Relationship briefing response was incomplete")
  end
end
