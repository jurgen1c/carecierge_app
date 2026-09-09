module EventPlans
  module LlmConfiguration
    DEFAULT_PROVIDER = "openai"
    DEFAULT_MODELS = Ai::Configuration::DEFAULT_MODELS

    module_function

    def provider
      normalize_provider(
        Rails.application.credentials.dig(:event_plans, :provider).presence ||
          ENV.fetch("CARECIERGE_EVENT_PLAN_PROVIDER", Ai::Configuration.provider)
      )
    end

    def model(provider: self.provider)
      chat_options(provider:).fetch(:model)
    end

    def chat_options(model: nil, provider: self.provider)
      provider = normalize_provider(provider)
      model_override = model.presence || (configured_model if provider == self.provider) ||
        Ai::Configuration.configured_model(provider:) || legacy_openai_model(provider)
      options = {
        model: (model_override || fallback_model(provider)).to_s,
        provider: provider.to_sym
      }
      options[:assume_model_exists] = true if model_override.present? || provider == "ollama"
      options
    end

    def response_params(provider:, output_token_limit:)
      case normalize_provider(provider)
      when "openai"
        { store: false, max_completion_tokens: output_token_limit }
      when "gemini"
        { generationConfig: { maxOutputTokens: output_token_limit } }
      when "ollama"
        { max_tokens: output_token_limit, reasoning_effort: "none" }
      else
        { max_tokens: output_token_limit }
      end
    end

    def configured_model
      Rails.application.credentials.dig(:event_plans, :model).presence ||
        ENV["CARECIERGE_EVENT_PLAN_MODEL"].presence
    end
    private_class_method :configured_model

    def normalize_provider(provider)
      provider.to_s.strip.downcase.presence || Ai::Configuration.provider
    end
    private_class_method :normalize_provider

    def legacy_openai_model(provider)
      return unless provider.to_s == "openai"

      Rails.application.credentials.dig(:openai, :event_plan_model).presence
    end
    private_class_method :legacy_openai_model

    def fallback_model(provider)
      Ai::Configuration.model(provider:)
    end
    private_class_method :fallback_model
  end
end
