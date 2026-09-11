require "rails_helper"

RSpec.describe "Local Ollama configuration" do
  it "can construct a native Ollama chat without any cloud API key" do
    context = RubyLLM.context do |config|
      config.openai_api_key = nil
      config.anthropic_api_key = nil
      config.gemini_api_key = nil
    end
    chat = context.chat(model: "qwen3:1.7b", provider: :ollama, assume_model_exists: true)

    expect(chat.model.id).to eq("qwen3:1.7b")
    expect(RubyLLM.config.ollama_api_base).to eq("http://127.0.0.1:11434/v1")
  end
end
