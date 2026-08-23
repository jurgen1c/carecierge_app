module EventPlans
  module LlmConfiguration
    DEFAULT_PROVIDER = "openai"
    DEFAULT_MODELS = {
      "openai" => "gpt-5-mini",
      "anthropic" => "claude-haiku-4-5",
      "gemini" => "gemini-2.5-flash"
    }.freeze

    module_function

    def provider
      normalize_provider(
        Rails.application.credentials.dig(:event_plans, :provider).presence ||
          ENV.fetch("CARECIERGE_EVENT_PLAN_PROVIDER", DEFAULT_PROVIDER)
      )
    end

    def model(provider: self.provider)
      chat_options(provider:).fetch(:model)
    end

    def chat_options(model: nil, provider: self.provider)
      provider = normalize_provider(provider)
      model_override = model.presence || configured_model || legacy_openai_model(provider)
      options = {
        model: (model_override || fallback_model(provider)).to_s,
        provider: provider.to_sym
      }
      options[:assume_model_exists] = true if model_override.present?
      options
    end

    def response_params(provider:, output_token_limit:)
      case normalize_provider(provider)
      when "openai"
        { store: false, max_completion_tokens: output_token_limit }
      when "gemini"
        { generationConfig: { maxOutputTokens: output_token_limit } }
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
      provider.to_s.strip.downcase.presence || DEFAULT_PROVIDER
    end
    private_class_method :normalize_provider

    def legacy_openai_model(provider)
      return unless provider.to_s == "openai"

      Rails.application.credentials.dig(:openai, :event_plan_model).presence
    end
    private_class_method :legacy_openai_model

    def fallback_model(provider)
      DEFAULT_MODELS.fetch(provider.to_s, DEFAULT_MODELS.fetch(DEFAULT_PROVIDER))
    end
    private_class_method :fallback_model
  end
end
