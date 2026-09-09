require "rails_helper"

RSpec.describe Ai::TextGeneration do
  let(:chat) { double("RubyLLM chat", with_instructions: nil, with_params: nil, with_schema: nil) }
  let(:context) { double("RubyLLM context", chat:) }

  before do
    allow(Ai::Configuration).to receive(:provider).and_return("ollama")
  end

  it "uses a bounded local timeout without content instrumentation or retrying against the cloud" do
    expect(RubyLLM).to receive(:context) do |&configure|
      config = RubyLLM.config.dup
      configure.call(config)
      expect(config.request_timeout).to eq(90)
      expect(config.max_retries).to eq(0)
      expect(config.instrumenter).to be_nil
      expect(config.log_stream_debug).to be(false)
      context
    end
    allow(chat).to receive(:ask).and_raise(Faraday::TimeoutError)

    expect do
      described_class.call(model: "carecierge-dev", instructions: "Private instructions", input: "Private text", output_token_limit: 20)
    end.to raise_error(Ai::GenerationError)
  end

  it "rejects truncated output even if it contains plausible text" do
    allow(RubyLLM).to receive(:context).and_return(context)
    raw = double(body: { "choices" => [ { "finish_reason" => "length" } ] })
    allow(chat).to receive(:ask).and_return(double(raw:, content: "A partly written draft"))

    expect do
      described_class.call(model: "carecierge-dev", instructions: "Draft", input: "Hello", output_token_limit: 20)
    end.to raise_error(Ai::GenerationError)
  end

  {
    "anthropic" => [ { "stop_reason" => "max_tokens" }, { "stop_reason" => "end_turn" } ],
    "gemini" => [ { "candidates" => [ { "finishReason" => "MAX_TOKENS" } ] }, { "candidates" => [ { "finishReason" => "STOP" } ] } ]
  }.each do |provider, (incomplete, complete)|
    it "rejects #{provider} truncation using its native completion status" do
      allow(Ai::Configuration).to receive(:provider).and_return(provider)
      allow(RubyLLM).to receive(:context).and_return(context)
      allow(chat).to receive(:ask).and_return(double(raw: double(body: incomplete), content: "How about we meet at"))
      expect do
        described_class.call(model: "test-model", instructions: "Draft", input: "Hello", output_token_limit: 20)
      end.to raise_error(Ai::GenerationError)
    end

    it "accepts a completed #{provider} response" do
      allow(Ai::Configuration).to receive(:provider).and_return(provider)
      allow(RubyLLM).to receive(:context).and_return(context)
      allow(chat).to receive(:ask).and_return(double(raw: double(body: complete), content: "How was your week?"))
      expect(described_class.call(model: "test-model", instructions: "Draft", input: "Hello", output_token_limit: 20)).to eq("How was your week?")
    end
  end

  it "rejects non-object structured output" do
    allow(RubyLLM).to receive(:context).and_return(context)
    allow(chat).to receive(:ask).and_return(double(raw: nil, content: []))

    expect do
      described_class.call(model: "carecierge-dev", instructions: "Extract", input: "Hello", output_token_limit: 20,
        schema: { name: "extract", schema: { type: "object" } })
    end.to raise_error(Ai::GenerationError)
  end
end
