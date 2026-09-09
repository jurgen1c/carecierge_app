require "rails_helper"

RSpec.describe "RubyLLM concierge agent", type: :service do
  let(:conversation) { ConciergeConversation.create!(user: create(:user)) }
  let(:turn) { conversation.turns.create!(content: "Hola", locale: "es", request_key: SecureRandom.uuid) }
  let(:chat) { double("RubyLLM chat") }
  let(:context) { double("RubyLLM context") }

  it "uses the local model default when only the concierge provider overrides an OpenAI event model" do
    allow(Rails.application.credentials).to receive(:dig).and_return(nil)
    allow(Rails.application.credentials).to receive(:dig).with(:concierge, :provider).and_return("ollama")
    allow(Rails.application.credentials).to receive(:dig).with(:event_plans, :provider).and_return("openai")
    allow(Rails.application.credentials).to receive(:dig).with(:event_plans, :model).and_return("gpt-5-mini")
    agent = Concierge::Agent.new
    agent.instance_variable_set(:@turn, turn)
    agent.instance_variable_set(:@token, turn.claim!)
    expect(agent.send(:configured_chat).model.id).to eq(Ai::Configuration.model(provider: "ollama"))
  end

  it "constructs the real installed RubyLLM chat with serialized tool execution" do
    allow(EventPlans::LlmConfiguration).to receive(:provider).and_return("ollama")
    agent = Concierge::Agent.new
    agent.instance_variable_set(:@turn, turn)
    agent.instance_variable_set(:@token, turn.claim!)

    native_chat = nil
    expect { native_chat = agent.send(:configured_chat) }.not_to raise_error
    expect(native_chat.params).to include(reasoning_effort: "low", max_tokens: 2_000)
  end

  it "uses the current locale, bounded tools, private provider configuration, and streaming" do
    expect(Concierge::ProviderChat).to receive(:new).with(hash_including(context:, before_request: a_kind_of(Method))).and_return(chat)
    expect(RubyLLM).to receive(:context) do |&configure|
      config = RubyLLM.config.dup
      configure.call(config)
      expect(config.instrumenter).to be_nil
      expect(config.log_stream_debug).to be(false)
      expect(config.request_timeout).to eq(30)
      context
    end
    expect(chat).to receive(:with_instructions).with(include("Spanish", "untrusted", "Never invent"))
    expect(chat).to receive(:with_params).with(hash_including(store: false))
    expect(chat).to receive(:with_tools) do |*tools, **options|
      expect(tools).to all(be_a(Concierge::Tool))
      expect(tools.map(&:name)).to contain_exactly("people_search", "people_read", "memories_search", "memories_create", "capabilities")
      expect(options).to include(concurrency: false)
    end
    allow(chat).to receive(:before_tool_call)
    after_message = nil
    allow(chat).to receive(:after_message) { |&callback| after_message = callback }
    allow(chat).to receive(:messages).and_return([])
    expect(chat).to receive(:ask).with("Hola") do |&stream|
      after_message.call(double(input_tokens: 10, output_tokens: 3))
      after_message.call(double(input_tokens: 4, output_tokens: 2))
      stream.call(double(content: "Hola"))
      double(content: "Hola", input_tokens: 4, output_tokens: 2)
    end
    token = turn.claim!
    chunks = []
    result = Concierge::Agent.new.call(turn:, token:) { |chunk| chunks << chunk }

    expect(result).to include(content: "Hola", input_tokens: 14, output_tokens: 5)
    expect(turn.reload).to have_attributes(input_tokens: 14, output_tokens: 5)
    expect(chunks).to eq([ "Hola" ])
  end

  it "does not expose raw tool arguments through RubyLLM's debug logger" do
    operation = Concierge::Catalog.fetch("people.search")
    tool = Concierge::Tool.new(operation:, turn:, token: turn.claim!)
    expect(RubyLLM).not_to receive(:logger)

    result = tool.call("query" => "Someone private")
    expect(result).to include("status" => "succeeded", "records" => [])
  end

  it "fails visibly for an empty provider response instead of completing a blank turn" do
    agent = Concierge::Agent.new
    allow(agent).to receive(:configured_chat).and_return(chat)
    allow(chat).to receive(:ask).and_return(double(content: ""))

    expect { agent.call(turn:, token: turn.claim!) }.to raise_error(Concierge::ProviderUnavailable)
  end

  it "uses non-streaming Ollama tool calls and publishes the completed text" do
    agent = Concierge::Agent.new
    agent.instance_variable_set(:@provider, "ollama")
    allow(agent).to receive(:configured_chat).and_return(chat)
    expect(chat).to receive(:ask).with("Hola") do |&stream|
      expect(stream).to be_nil
      double(content: "Hola")
    end
    chunks = []

    result = agent.call(turn:, token: turn.claim!) { |text| chunks << text }

    expect(result).to include(content: "Hola")
    expect(chunks).to eq([ "Hola" ])
  end
end
