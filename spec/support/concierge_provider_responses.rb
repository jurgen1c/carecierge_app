# Script only the provider's HTTP boundary. RubyLLM still serializes requests,
# parses JSON/SSE, dispatches tools and sends their real results back to the model.
class ConciergeProviderResponses
  attr_reader :requests, :adapter

  def initialize
    @steps = []
    @requests = []
    @call_number = 0
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("https://concierge-provider.invalid/v1/chat/completions") do |env|
      payload = JSON.parse(env.body)
      @requests << payload
      step = @steps.shift || raise("Unexpected provider request; the response script is exhausted")
      response = step.call(payload)
      if response.is_a?(Array)
        response
      elsif payload.fetch("stream")
        stream(env, response)
      else
        [ 200, { "Content-Type" => "application/json" }, JSON.generate(response) ]
      end
    end
    @adapter = Class.new(Faraday::Adapter::Test) do
      define_method(:initialize) { |app| super(app, stubs) }
    end
  end

  def next_response(&block)
    @steps << block
  end

  def tool(name, arguments = {})
    @call_number += 1
    completion({ role: "assistant", content: nil, tool_calls: [ {
      id: "call_#{@call_number}", type: "function", function: { name:, arguments: JSON.generate(arguments) }
    } ] }, finish_reason: "tool_calls")
  end

  def answer(content)
    completion({ role: "assistant", content: }, finish_reason: "stop")
  end

  def tool_result(payload)
    message = payload.fetch("messages").last
    raise "Expected the real tool result" unless message.fetch("role") == "tool"

    # RubyLLM 1.16 sends Hash results as Ruby text, not JSON. Treat the wire
    # content as text just as the model does; never eval provider/record content.
    message.fetch("content")
  end

  def verify!
    raise "#{@steps.length} scripted provider responses were not consumed" unless @steps.empty?
  end

  private

  def completion(message, finish_reason:)
    { id: "completion_#{requests.length}", object: "chat.completion", model: "test-concierge",
      choices: [ { index: 0, message:, finish_reason: } ],
      usage: { prompt_tokens: 10, completion_tokens: 3, total_tokens: 13 } }.deep_stringify_keys
  end

  def stream(env, response)
    message = response.fetch("choices").first.fetch("message")
    # Split tool arguments across SSE events, and events across transport chunks.
    # This exercises the gem's actual accumulator rather than returning a Message double.
    deltas = if message["tool_calls"]
      message.fetch("tool_calls").each_with_index.flat_map do |original, index|
        call = original.deep_dup
        arguments = call.fetch("function").fetch("arguments")
        split = arguments.length / 2
        call["index"] = index
        call["function"]["arguments"] = arguments.first(split)
        [ { "role" => "assistant", "tool_calls" => [ call ] },
          { "tool_calls" => [ { "index" => index, "function" => { "arguments" => arguments[split..] } } ] } ]
      end
    else
      content = message["content"].to_s
      split = content.length / 2
      [ { "role" => "assistant", "content" => content.first(split) }, { "content" => content[split..] } ]
    end
    events = deltas.map do |delta|
      response.slice("id", "model").merge("object" => "chat.completion.chunk",
        "choices" => [ { "index" => 0, "delta" => delta } ])
    end
    events << response.slice("id", "model", "usage").merge("choices" => [ {
      "index" => 0, "delta" => {}, "finish_reason" => response.fetch("choices").first.fetch("finish_reason")
    } ])
    data = events.map { |event| "data: #{JSON.generate(event)}\n\n" }.join + "data: [DONE]\n\n"
    env.status = 200
    env.response_headers = { "Content-Type" => "text/event-stream" }
    bytes = 0
    data.scan(/.{1,37}/m).each do |chunk|
      bytes += chunk.bytesize
      env.request.on_data.call(chunk, bytes, env)
    end
    [ 200, env.response_headers, "" ]
  end
end
