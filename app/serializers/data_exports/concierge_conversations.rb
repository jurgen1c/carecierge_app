module DataExports
  class ConciergeConversations
    def initialize(user:, relationship_profile: nil, include_sensitive: false)
      @user, @profile, @include_sensitive = user, relationship_profile, include_sensitive
    end

    def to_a
      @user.concierge_conversations.order(:created_at, :id).includes(turns: :actions).filter_map do |conversation|
        turns = conversation.turns.sort_by { |turn| [ turn.created_at, turn.id ] }
        turns.select! { |turn| turn.referenced_profile_ids == [ @profile.id ] } if @profile
        next if @profile && turns.empty?
        values = turns.map { |turn| turn_attributes(turn) }
        {
          "id" => conversation.id,
          "title" => @profile || values.any? { |value| value["content_redacted"] } ? nil : conversation.title,
          "created_at" => conversation.created_at,
          "turns" => values
        }
      end
    end

    private

    def turn_attributes(turn)
      value = turn.attributes.slice("id", "locale", "state", "created_at", "finished_at")
      unless content_available?(turn)
        return value.merge("content_redacted" => true)
      end
      value.merge("content" => turn.content, "response" => turn.response,
        "actions" => turn.actions.map do |action|
          action.attributes.slice("id", "name", "state", "created_at", "decided_at").merge(
            "arguments" => action.arguments,
            "result" => action.result.except("action_id", "operation", "arguments", "preview")
          )
        end)
    end

    def content_available?(turn)
      protected_context = Array(turn.context["vault_item_ids"]).any?
      return false if protected_context && !@include_sensitive

      checked_turn = turn
      if protected_context
        # Prepare has reauthenticated a sensitive export. Check current source selection
        # with an ephemeral lease; never export or extend the conversation's stored lease.
        checked_turn = Concierge::ExportTurn.new(turn:, vault_lease: PrivacyVault::Lease.issue_for(@user))
      end
      Concierge::Context.verify!(turn: checked_turn)
      Concierge::History.sources_current?(checked_turn)
    rescue Concierge::Error, ActiveRecord::RecordNotFound
      false
    end
  end
end
