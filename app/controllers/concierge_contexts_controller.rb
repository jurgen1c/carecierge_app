class ConciergeContextsController < ApplicationController
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  before_action :set_context
  rate_limit to: 20, within: 1.minute, by: -> { current_user.id }, only: :update
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def edit
  end

  def update
    updated = Concierge::ConfigureContext.call(user: current_user, conversation: @conversation,
      attributes: context_params.to_h, expected_version: params.permit(:expected_version)[:expected_version])
    redirect_to concierge_conversation_path(updated), notice: t("concierge.relationship_context.saved"), status: :see_other
  rescue ActiveRecord::RecordInvalid, Concierge::Error => error
    @error_message = error.is_a?(Concierge::Error) ? t("concierge.errors.#{error.code}") : t("concierge.relationship_context.invalid")
    @relationship_profile.reload
    render :edit, status: :unprocessable_content
  end

  private

  def set_context
    @conversation = policy_scope(ConciergeConversation).find(params[:concierge_conversation_id])
    authorize @conversation, :update?
    @relationship_profile = current_user.relationship_profiles.active.find(@conversation.relationship_profile_id)
  end

  def context_params
    params.require(:relationship_profile).permit(:relationship_mode,
      professional_context: [ *ProfessionalContext::FIELDS, :gifts_allowed, ProfessionalContext::COLLECTIONS.index_with { [] } ])
  end
end
