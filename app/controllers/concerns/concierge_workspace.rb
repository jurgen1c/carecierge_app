module ConciergeWorkspace
  extend ActiveSupport::Concern
  PAGE_SIZE = 30

  private

  def prepare_concierge_workspace
    @profiles = current_user.relationship_profiles.active.ordered.limit(100).to_a
    @history_pagy, history = concierge_page(policy_scope(ConciergeConversation).recent_first, "history_page")
    @history = history.to_a
    @history_first_turns = ConciergeTurn.where(conversation_id: @history.map(&:id))
      .select("DISTINCT ON (conversation_id) concierge_turns.*").order(:conversation_id, :created_at, :id).index_by(&:conversation_id)
    if @conversation.persisted?
      @turns_pagy, turns = concierge_page(@conversation.turns.order(created_at: :desc, id: :desc).includes(:actions), "turn_page")
      @turns = turns.to_a.reverse
    else
      @turns = []
    end
    @request_key = SecureRandom.uuid
    profile = @conversation.relationship_profile
    @profiles << profile if profile && profile.user_id == current_user.id && !profile.discarded? && @profiles.none? { |choice| choice.id == profile.id }
    @private_notes = @vault_items = []
    if profile
      private_scope = profile.relationship_notes.where(private: true).where.missing(:privacy_vault_item).with_rich_text_body.order(:created_at, :id)
      @private_notes_pagy, notes = concierge_page(private_scope, "private_notes_page", limit: 20)
      @private_notes = notes.to_a
      @vault_items_pagy, items = concierge_page(profile.privacy_vault_items.suggestion_allowed.order(:created_at, :id), "vault_items_page", limit: 20)
      @vault_items = items.to_a
    end
  end

  def context_page_request?
    turbo_frame_request? && params[:context_kind].present?
  end

  def render_context_page
    kind = params[:context_kind]
    return head :bad_request unless kind.in?(%w[private_notes vault_items])
    return head :forbidden unless @conversation.relationship_profile && !@conversation.relationship_profile.professional?
    return head :forbidden if kind == "vault_items" && !privacy_vault_unlocked?

    records, pagination = kind == "private_notes" ? [ @private_notes, @private_notes_pagy ] : [ @vault_items, @vault_items_pagy ]
    render "concierge_conversations/context_page", layout: false, locals: { kind:, records:, pagination: }
  end

  def concierge_page(scope, key, limit: PAGE_SIZE)
    value = params[key]
    page = Integer(value, exception: false) if value.is_a?(String) || value.is_a?(Integer)
    count = scope.count
    last_page = [ count.fdiv(limit).ceil, 1 ].max
    pagy(:offset, scope, limit:, count:, page_key: key, page: page&.between?(1, last_page) ? page : 1)
  end
end
