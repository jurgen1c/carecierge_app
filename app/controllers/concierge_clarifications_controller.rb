class ConciergeClarificationsController < ApplicationController
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, only: :create
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def create
    @conversation = policy_scope(ConciergeConversation).find(params[:concierge_conversation_id])
    authorize @conversation, :update?
    input = params.permit(:action_id, :relationship_profile_id)
    action = ConciergeAction.joins(:turn).where(concierge_turns: { conversation_id: @conversation.id }).find(input[:action_id])
    Concierge::Clarify.call(user: current_user, action:, relationship_profile_id: input[:relationship_profile_id])
    redirect_to concierge_conversation_path(@conversation), status: :see_other
  rescue Concierge::Error => error
    redirect_to concierge_conversation_path(@conversation), alert: t("concierge.errors.#{error.code}"), status: :see_other
  end
end
