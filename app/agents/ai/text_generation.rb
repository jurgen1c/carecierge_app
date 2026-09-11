module Ai
  class TextGeneration
    def self.call(model:, instructions:, input:, output_token_limit:, schema: nil, images: [])
      provider = Configuration.provider
      context = RubyLLM.context do |config|
        config.instrumenter = nil
        config.log_level = :warn
        config.log_stream_debug = false
        config.request_timeout = Configuration.request_timeout(provider:)
        config.max_retries = provider == "ollama" ? 0 : 1
      end
      chat = context.chat(model:, provider: provider.to_sym, assume_model_exists: true)
      chat.with_instructions(instructions)
      chat.with_schema(schema) if schema
      chat.with_params(**EventPlans::LlmConfiguration.response_params(provider:, output_token_limit:))
      response = chat.ask(input, with: images.presence)
      validate_completion!(response, provider:)

      content = response.content
      if schema
        raise GenerationError unless content.is_a?(Hash)

        content.deep_stringify_keys
      else
        raise GenerationError unless content.is_a?(String) && content.present?

        content.strip
      end
    rescue RubyLLM::Error, RubyLLM::ConfigurationError, RubyLLM::ModelNotFoundError, Faraday::Error, JSON::ParserError
      raise GenerationError, "AI provider was unavailable"
    end

    def self.validate_completion!(response, provider:)
      body = response.raw&.body
      reason, completed = case provider
      when "anthropic" then [ body&.dig("stop_reason"), %w[end_turn stop_sequence] ]
      when "gemini" then [ body&.dig("candidates", 0, "finishReason"), %w[STOP] ]
      else [ body&.dig("choices", 0, "finish_reason"), %w[stop] ]
      end
      raise GenerationError if reason.present? && !reason.in?(completed)
    end
    private_class_method :validate_completion!
  end
end
