module Concierge
  class Respond
    def self.call(turn:, agent: nil)
      token = turn.claim!
      return unless token

      I18n.with_locale(turn.locale) do
        Time.use_zone(OwnerLocalCalendar.time_zone_for(user: turn.conversation.user)) do
          verify_response!(turn)
          response = (agent || Agent.new).call(turn:, token:) do |text|
            verify_response!(turn)
            raise ExecutionExpired unless turn.append_response!(token:, text:)
          end
          verify_response!(turn)
          turn.finish!(token:, response: response.fetch(:content),
            input_tokens: response.fetch(:input_tokens, 0), output_tokens: response.fetch(:output_tokens, 0))
        end
      end
      ActiveSupport::Notifications.instrument("concierge.turn_completed", state: turn.state,
        attempts: turn.attempts, input_tokens: turn.input_tokens, output_tokens: turn.output_tokens)
    rescue Error => error
      turn.fail!(token:, error_code: error.code)
      ActiveSupport::Notifications.instrument("concierge.turn_failed", error_code: error.code)
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def self.verify_response!(turn)
      Context.verify!(turn:)
      raise ContextUnavailable unless History.sources_current?(turn)
    end
  end
end
