module Concierge
  class Retry
    def self.call(user:, turn:)
      conversation = turn.conversation
      Pundit.authorize(user, conversation, :update?)
      user.with_lock("FOR NO KEY UPDATE") do
        conversation.lock!
        Context.verify!(turn:)
        if conversation.turns.where(state: %w[queued running]).where.not(id: turn.id).exists?
          raise ConversationBusy
        end
        ConciergeResponseJob.perform_later(turn.id) if turn.retry!
      end
    end
  end
end
