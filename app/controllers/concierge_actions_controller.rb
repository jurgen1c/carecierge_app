class ConciergeActionsController < ApplicationController
  include PrivacyVaultSession
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def update
    @conversation = policy_scope(ConciergeConversation).find(params[:concierge_conversation_id])
    authorize @conversation, :update?
    action = ConciergeAction.joins(:turn).where(concierge_turns: { conversation_id: @conversation.id }).find(params[:id])
    raise Concierge::VaultLocked if Array(action.turn.context["vault_item_ids"]).any? && !privacy_vault_unlocked?
    Concierge::Decide.call(user: current_user, action:, decision: params[:decision], fingerprint: params[:fingerprint])
    redirect_to concierge_conversation_path(@conversation), status: :see_other
  rescue Concierge::Error => error
    redirect_to concierge_conversation_path(@conversation), alert: t("concierge.errors.#{error.code}"), status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to concierge_conversation_path(@conversation), alert: t("concierge.errors.invalid_arguments"), status: :see_other
  rescue ActiveRecord::StaleObjectError
    redirect_to concierge_conversation_path(@conversation), alert: t("concierge.errors.request_conflict"), status: :see_other
  end
end
