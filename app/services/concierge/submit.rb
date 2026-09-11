module Concierge
  class Submit
    def self.call(user:, conversation:, content:, request_key:, locale:, context: {}, vault_lease: nil)
      Pundit.authorize(user, conversation, :update?)
      user.with_lock("FOR NO KEY UPDATE") do
        conversation.lock!
        Pundit.authorize(user, conversation, :update?)

        existing = conversation.turns.find_by(request_key:)
        if existing
          raise RequestConflict unless existing.content == content && existing.locale == locale.to_s
          next existing
        end
        pending = conversation.turns.where(state: %w[queued running])
        pending.where(attempts: ConciergeTurn::MAX_ATTEMPTS..).find_each(&:expire_exhausted!)
        raise ConversationBusy if pending.exists?

        snapshot = Context.capture(user:, conversation:, selections: context.deep_stringify_keys, vault_lease:)
        turn = conversation.turns.create!(content:, request_key:, locale:, context: snapshot)
        title = if Array(snapshot["vault_item_ids"]).any?
          I18n.t("concierge.new_conversation", locale:)
        else
          content.to_s.squish.first(100)
        end
        conversation.update!(title: conversation.title.presence || title, updated_at: Time.current)
        ConciergeResponseJob.perform_later(turn.id)
        turn
      end
    end
  end
end
