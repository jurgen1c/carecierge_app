RubyLLM.configure do |config|
  credentials = Rails.application.credentials

  config.openai_api_key = credentials.dig(:openai, :api_key).presence || ENV["OPENAI_API_KEY"]
  config.anthropic_api_key = credentials.dig(:anthropic, :api_key).presence || ENV["ANTHROPIC_API_KEY"]
  config.gemini_api_key = credentials.dig(:gemini, :api_key).presence || ENV["GEMINI_API_KEY"]
  config.ollama_api_base = credentials.dig(:ollama, :api_base).presence || ENV["OLLAMA_API_BASE"].presence || "http://127.0.0.1:11434/v1"
  config.ollama_api_key = credentials.dig(:ollama, :api_key).presence || ENV["OLLAMA_API_KEY"]
  config.use_new_acts_as = true
  config.request_timeout = Rails.env.development? ? 90 : 30
  config.max_retries = 2
  config.log_level = :warn
end
