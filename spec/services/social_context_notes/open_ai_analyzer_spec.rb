require "rails_helper"

RSpec.describe SocialContextNotes::OpenAiAnalyzer do
  it "sends bounded user text and embedded images in a non-stored structured Responses request" do
    note = create(:social_context_note, body: "Maya shared a screenshot about a bookstore event.")
    image = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("image bytes"),
      filename: "event.png",
      content_type: "image/png"
    )
    note.body = "<p>Maya shared a screenshot about a bookstore event.</p>#{ActionText::Attachment.from_attachable(image).to_html}"
    note.save!
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
                interpretation: "The bookstore event may be a comfortable conversation topic.",
                suggested_uses: %w[message conversation_topic]
              )
            }
          ]
        }
      ]
    ))
    response.instance_variable_set(:@read, true)
    request = nil

    input = SocialContextNotes::AnalysisInput.new(
      text: note.body.to_plain_text.squish,
      image_blob_ids: [ image.id ]
    )
    result = described_class.new(
      api_key: "test-key",
      model: "test-model",
      transport: ->(outbound_request) { request = outbound_request; response }
    ).analyze(input:, locale: :en)

    payload = JSON.parse(request.body)
    content = payload.dig("input", 0, "content")
    expect(payload).to include("model" => "test-model", "store" => false)
    expect(payload.dig("text", "format", "type")).to eq("json_schema")
    expect(payload.dig("text", "format", "schema", "properties", "suggested_uses")).not_to have_key("uniqueItems")
    expect(content.first).to include("type" => "input_text", "text" => a_string_including("bookstore event"))
    expect(content.second).to include(
      "type" => "input_image",
      "image_url" => "data:image/png;base64,#{Base64.strict_encode64('image bytes')}",
      "detail" => "low"
    )
    expect(result).to eq(
      interpretation: "The bookstore event may be a comfortable conversation topic.",
      suggested_uses: %w[message conversation_topic]
    )
  end

  it "fails closed for missing credentials, incomplete output, and invalid suggested uses" do
    input = SocialContextNotes::AnalysisInput.new(text: "Bookstore context", image_blob_ids: [])

    expect do
      described_class.new(api_key: "").analyze(input:)
    end.to raise_error(SocialContextNotes::AnalysisError, "Social context analysis is not configured")

    incomplete = Net::HTTPOK.new("1.1", "200", "OK")
    incomplete.instance_variable_set(:@body, JSON.generate(status: "incomplete", output: []))
    incomplete.instance_variable_set(:@read, true)
    expect do
      described_class.new(api_key: "key", transport: ->(_) { incomplete }).analyze(input:)
    end.to raise_error(SocialContextNotes::AnalysisError, "Social context analysis was incomplete")

    invalid = Net::HTTPOK.new("1.1", "200", "OK")
    invalid.instance_variable_set(:@body, JSON.generate(
      status: "completed",
      output: [
        { type: "message", content: [ { type: "output_text", text: JSON.generate(interpretation: "Profile them", suggested_uses: [ "profile_score" ]) } ] }
      ]
    ))
    invalid.instance_variable_set(:@read, true)
    expect do
      described_class.new(api_key: "key", transport: ->(_) { invalid }).analyze(input:)
    end.to raise_error(SocialContextNotes::AnalysisError, "Social context analysis response was invalid")

    scalar = Net::HTTPOK.new("1.1", "200", "OK")
    scalar.instance_variable_set(:@body, JSON.generate(
      status: "completed",
      output: [ { type: "message", content: [ { type: "output_text", text: "null" } ] } ]
    ))
    scalar.instance_variable_set(:@read, true)
    expect do
      described_class.new(api_key: "key", transport: ->(_) { scalar }).analyze(input:)
    end.to raise_error(SocialContextNotes::AnalysisError, "Social context analysis response was invalid")
  end

  it "turns screenshot storage failures into a recoverable analysis error" do
    image = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("missing image"),
      filename: "missing.png",
      content_type: "image/png"
    )
    input = SocialContextNotes::AnalysisInput.new(text: "Bookstore context", image_blob_ids: [ image.id ])
    allow(ActiveStorage::Blob.service).to receive(:download).and_raise(ActiveStorage::FileNotFoundError)
    transport = double
    expect(transport).not_to receive(:call)

    expect do
      described_class.new(api_key: "key", transport:).analyze(input:)
    end.to raise_error(SocialContextNotes::AnalysisError, "Social context screenshot could not be read")
  end
end
