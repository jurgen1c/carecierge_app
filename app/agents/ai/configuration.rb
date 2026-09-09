module Ai
  module Configuration
    DEFAULT_MODELS = {
      "openai" => "gpt-5-mini",
      "ollama" => "carecierge-dev",
      "anthropic" => "claude-haiku-4-5",
      "gemini" => "gemini-2.5-flash"
    }.freeze

    module_function

    def provider
      configured = Rails.application.credentials.dig(:ai, :provider).presence || ENV["CARECIERGE_AI_PROVIDER"].presence
      configured.to_s.strip.downcase.presence || (Rails.env.development? ? "ollama" : "openai")
    end

    def configured_model(provider: self.provider)
      return unless provider.to_s.strip.downcase == self.provider

      Rails.application.credentials.dig(:ai, :model).presence || ENV["CARECIERGE_AI_MODEL"].presence
    end

    def model(provider: self.provider)
      provider = provider.to_s.strip.downcase
      configured_model(provider:) || (ENV["CARECIERGE_OLLAMA_MODEL"].presence if provider == "ollama") ||
        DEFAULT_MODELS.fetch(provider) { raise RubyLLM::ConfigurationError, "Configure a model for the selected AI provider" }
    end

    def request_timeout(provider: self.provider)
      provider.to_s.strip.downcase == "ollama" ? 90 : 30
    end
  end
end
