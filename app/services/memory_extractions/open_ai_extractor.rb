require "json"
require "net/http"

module MemoryExtractions
  class OpenAiExtractor
    ENDPOINT = URI("https://api.openai.com/v1/responses")
    DEFAULT_MODEL = "gpt-5-mini"
    REQUEST_TIMEOUT = 30

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      properties: {
        memories: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              category: { type: "string", enum: ExtractedMemory::CATEGORIES },
              title: { type: "string" },
              body: { type: "string" },
              source_excerpt: { type: "string" },
              confidence: { type: "string", enum: ExtractedMemory::CONFIDENCES }
            },
            required: %w[category title body source_excerpt confidence]
          }
        }
      },
      required: [ "memories" ]
    }.freeze

    def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("CARECIERGE_MEMORY_EXTRACTION_MODEL", DEFAULT_MODEL), transport: nil)
      @api_key = api_key.to_s
      @model = model.to_s
      @transport = transport || method(:perform_request)
    end

    def extract(conversation_recap)
      raise ExtractionError, "AI extraction is not configured" if api_key.blank?

      response = transport.call(build_request(conversation_recap))
      raise ExtractionError, "AI extraction request failed" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      memories = JSON.parse(output_text(parsed)).fetch("memories")
      raise ExtractionError, "AI extraction response was invalid" unless memories.is_a?(Array)

      memories
    rescue JSON::ParserError, KeyError, TypeError
      raise ExtractionError, "AI extraction response was invalid"
    end

    private

    attr_reader :api_key, :model, :transport

    def build_request(conversation_recap)
      request = Net::HTTP::Post.new(ENDPOINT)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        model:,
        store: false,
        instructions: instructions,
        input: source_text(conversation_recap),
        text: {
          format: {
            type: "json_schema",
            name: "relationship_memory_proposals",
            strict: true,
            schema: SCHEMA
          }
        }
      )
      request
    end

    def instructions
      <<~PROMPT.squish
        Extract only relationship memories explicitly supported by the source. Categories are preference,
        important_date, desire, commitment, gift_idea, boundary, and emotional_context. Preserve a short exact
        source excerpt for each proposal. Use high only for direct explicit statements, medium for clear context,
        low for tentative statements, and inferred when interpretation is required. Do not infer sensitive traits,
        diagnoses, identity, or high-impact conclusions. Return no proposal when the source is insufficient.
      PROMPT
    end

    def source_text(conversation_recap)
      [
        "Recap title: #{conversation_recap.title}",
        "Recap: #{conversation_recap.body}",
        ("Transcript: #{conversation_recap.transcript}" if conversation_recap.transcript.present?)
      ].compact.join("\n\n")
    end

    def output_text(parsed)
      parsed.fetch("output").filter_map do |item|
        next unless item["type"] == "message"

        Array(item["content"]).find { |content| content["type"] == "output_text" }&.fetch("text", nil)
      end.compact.first || raise(ExtractionError, "AI extraction response did not contain output")
    end

    def perform_request(request)
      Net::HTTP.start(
        ENDPOINT.host,
        ENDPOINT.port,
        use_ssl: true,
        open_timeout: REQUEST_TIMEOUT,
        read_timeout: REQUEST_TIMEOUT,
        write_timeout: REQUEST_TIMEOUT
      ) { |http| http.request(request) }
    rescue Timeout::Error, SocketError, SystemCallError, IOError
      raise ExtractionError, "AI extraction provider was unavailable"
    end
  end
end
