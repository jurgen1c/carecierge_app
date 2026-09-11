module Concierge
  class ProviderChat < RubyLLM::Chat
    module CheckedStreaming
      def stream_response(...)
        @concierge_completion_seen = false
        super.tap { raise ProviderUnavailable unless @concierge_completion_seen }
      ensure
        @concierge_completion_seen = nil
      end

      def build_chunk(data)
        completed = ProviderChat.verify_completion!(data)
        @concierge_completion_seen = true if completed
        super
      end
    end

    def initialize(before_request:, **options)
      @before_request = before_request
      super(**options)
      # Extend only this chat's provider instance. RubyLLM drops termination
      # metadata when it accumulates stream chunks into the final message.
      @provider.extend(CheckedStreaming)
    end

    def self.verify_completion!(body, required: false)
      raise ProviderUnavailable if required && !body.is_a?(Hash)
      return false unless body.is_a?(Hash)

      reasons = [ body.dig("choices", 0, "finish_reason"), body["stop_reason"],
        body.dig("delta", "stop_reason"), body.dig("candidates", 0, "finishReason") ].compact_blank
      allowed = %w[stop tool_calls end_turn stop_sequence tool_use STOP]
      raise ProviderUnavailable if (required && reasons.empty?) || reasons.any? { |reason| !reason.in?(allowed) }
      reasons.any?
    end

    private

    # RubyLLM's before_message callback runs after non-streaming HTTP requests.
    # Guard the shared provider boundary for both streaming and local requests.
    def provider_completion(&)
      @before_request.call(self)
      super.tap { |response| self.class.verify_completion!(response.raw&.body, required: !block_given?) }
    end
  end
end
