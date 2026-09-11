class ConciergeTurnsController < ApplicationController
  include PrivacyVaultSession
  include ConciergeWorkspace

  before_action :set_conversation
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, only: %i[create retry]

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def create
    input = params.require(:concierge_message).permit(:content, :request_key, private_note_ids: [], vault_item_ids: [])
    Concierge::Submit.call(user: current_user, conversation: @conversation, content: input[:content],
      request_key: input[:request_key], locale: I18n.locale,
      context: input.slice(:private_note_ids, :vault_item_ids).to_h, vault_lease: privacy_vault_lease)
    redirect_to concierge_conversation_path(@conversation), status: :see_other
  rescue ActiveRecord::RecordInvalid, Concierge::Error => error
    @error_code = error.is_a?(Concierge::Error) ? error.code : "invalid_message"
    @content = input[:content]
    prepare_concierge_workspace
    render "concierge_conversations/index", formats: [ :html ], content_type: "text/html", status: :unprocessable_content
  end

  def retry
    turn = @conversation.turns.find(params[:id])
    raise Concierge::VaultLocked if Array(turn.context["vault_item_ids"]).any? && !privacy_vault_unlocked?
    Concierge::Retry.call(user: current_user, turn:)
    redirect_to concierge_conversation_path(@conversation), status: :see_other
  rescue Concierge::Error => error
    redirect_to concierge_conversation_path(@conversation), alert: t("concierge.errors.#{error.code}"), status: :see_other
  end

  private

  def set_conversation
    @conversation = policy_scope(ConciergeConversation).find(params[:concierge_conversation_id])
    authorize @conversation, :update?
  end
end
