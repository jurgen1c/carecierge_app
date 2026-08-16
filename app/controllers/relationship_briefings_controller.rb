class RelationshipBriefingsController < ApplicationController
  include PrivacyVaultSession
  include RelationshipProfileShowWorkspace

  rate_limit to: 6, within: 1.minute, by: -> { current_user.id }, only: :generate

  before_action :set_relationship_profile
  before_action :set_relationship_briefing, only: %i[save dismiss]

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def generate
    authorize @relationship_profile, :update?
    return require_vault_unlock if include_vault_context? && !touch_privacy_vault_lease!

    RelationshipBriefings::Generate.call(
      actor: current_user,
      relationship_profile: @relationship_profile,
      interaction_context: briefing_params[:interaction_context],
      include_private_notes: include_private_notes?,
      include_vault_context: include_vault_context?,
      vault_lease: privacy_vault_lease,
      locale: I18n.locale
    )

    redirect_to workspace_path, notice: t("relationship_briefings.generate.notice")
  rescue RelationshipBriefings::VaultAccessError
    require_vault_unlock
  rescue RelationshipBriefings::GenerationSupersededError
    render_generation_error("relationship_briefings.generate.superseded")
  rescue RelationshipBriefings::GenerationError
    render_generation_error("relationship_briefings.generate.provider_error")
  rescue ActiveRecord::RecordInvalid
    render_generation_error("relationship_briefings.generate.invalid")
  end

  def save
    authorize @relationship_briefing, :update?
    transition_briefing("relationship_briefing.saved", &:save_for_later!)

    redirect_to workspace_path, notice: t("relationship_briefings.save.notice")
  rescue ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("relationship_briefings.save.unavailable")
  end

  def dismiss
    authorize @relationship_briefing, :destroy?
    transition_briefing("relationship_briefing.dismissed", &:dismiss!)

    redirect_to workspace_path, notice: t("relationship_briefings.dismiss.notice")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.kept.friendly.find(params[:relationship_profile_id])
  end

  def set_relationship_briefing
    @relationship_briefing = @relationship_profile.relationship_briefings.find(params[:id])
  end

  def briefing_params
    params.require(:relationship_briefing).permit(:interaction_context, :include_private_notes, :include_vault_context)
  end

  def include_private_notes?
    ActiveModel::Type::Boolean.new.cast(briefing_params[:include_private_notes]) || false
  end

  def include_vault_context?
    ActiveModel::Type::Boolean.new.cast(briefing_params[:include_vault_context]) || false
  end

  def require_vault_unlock
    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: t("privacy_vaults.access_required")
  end

  def workspace_path
    relationship_profile_path(@relationship_profile, anchor: "relationship-briefing")
  end

  def record_action(action)
    AuditEvent.record!(
      user: current_user,
      actor: current_user,
      action:,
      target: @relationship_profile,
      metadata: { result: @relationship_briefing.status }
    )
  end

  def transition_briefing(action)
    current_user.with_lock do
      @relationship_profile.lock!
      yield @relationship_briefing
      record_action(action)
    end
  end

  def render_generation_error(translation_key)
    @relationship_briefing_form_state = briefing_params.to_h.symbolize_keys
    prepare_relationship_profile_show
    flash.now[:alert] = t(translation_key)
    render "relationship_profiles/show", status: :unprocessable_content
  end
end
