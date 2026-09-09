# Adapted from RubyLLM's chat_ui ChatResponseJob. Persisted IDs keep private
# content out of job arguments; the application runner owns authorization/retry.
class ConciergeResponseJob < ApplicationJob
  def perform(turn_id)
    turn = ConciergeTurn.find_by(id: turn_id)
    Concierge::Respond.call(turn:) if turn
  end
end
