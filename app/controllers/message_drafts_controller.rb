class MessageDraftsController < ApplicationController
  include PrivacyVaultSession

  rate_limit to: 10, within: 1.minute, by: -> { current_user.id }, only: :generate

  before_action :set_relationship_profile
  before_action :set_message_draft, only: %i[update restore destroy]

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def generate
    authorize @relationship_profile, :update?
    return require_vault_unlock if use_vault_context? && !touch_privacy_vault_lease!

    MessageDrafts::Generate.call(
      actor: current_user,
      relationship_profile: @relationship_profile,
      draft_type: generation_params[:draft_type],
      tone: generation_params[:tone],
      situation: generation_params[:situation],
      response_length: generation_params[:response_length],
      formality: generation_params[:formality],
      include_private_notes: use_private_notes?,
      include_vault_context: use_vault_context?,
      vault_lease: privacy_vault_lease,
      locale: I18n.locale
    )

    redirect_to workspace_path, notice: t("message_drafts.generate.notice")
  rescue MessageDrafts::VaultAccessError
    require_vault_unlock
  rescue MessageDrafts::GenerationSupersededError
    redirect_to workspace_path, alert: t("message_drafts.generate.superseded")
  rescue MessageDrafts::GenerationError
    redirect_to workspace_path, alert: t("message_drafts.generate.provider_error")
  rescue ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("message_drafts.generate.invalid")
  end

  def update
    authorize @message_draft
    attributes = update_params
    @message_draft.save_edit!(
      content: attributes[:content],
      draft_type: attributes[:draft_type],
      tone: attributes[:tone],
      **attributes.slice(:situation, :response_length, :formality).to_h.symbolize_keys
    )

    redirect_to workspace_path, notice: t("message_drafts.update.notice")
  rescue ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("message_drafts.update.invalid")
  end

  def restore
    authorize @message_draft, :update?
    revision = @message_draft.draft_revisions.find(params[:revision_id])
    @message_draft.restore_revision!(revision)

    redirect_to workspace_path, notice: t("message_drafts.restore.notice")
  end

  def destroy
    authorize @message_draft
    @message_draft.destroy!

    redirect_to workspace_path, notice: t("message_drafts.destroy.notice")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.kept.friendly.find(params[:relationship_profile_id])
  end

  def set_message_draft
    @message_draft = @relationship_profile.message_draft
    raise ActiveRecord::RecordNotFound unless @message_draft
  end

  def generation_params
    params.require(:message_draft).permit(
      :draft_type,
      :tone,
      :situation,
      :response_length,
      :formality,
      :use_private_notes,
      :use_vault_context
    )
  end

  def update_params
    params.require(:message_draft).permit(:content, :draft_type, :tone, :situation, :response_length, :formality)
  end

  def use_private_notes?
    ActiveModel::Type::Boolean.new.cast(generation_params[:use_private_notes])
  end

  def use_vault_context?
    ActiveModel::Type::Boolean.new.cast(generation_params[:use_vault_context])
  end

  def require_vault_unlock
    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: t("privacy_vaults.access_required")
  end

  def workspace_path
    relationship_profile_path(@relationship_profile, anchor: "message-drafting")
  end
end
