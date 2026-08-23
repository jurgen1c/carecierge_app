class BackupPlansController < ApplicationController
  include PrivacyVaultSession

  rate_limit to: 6, within: 1.minute, by: -> { current_user.id }, only: :generate

  before_action :set_event_plan
  before_action :set_backup_plan, only: :promote

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def generate
    authorize @event_plan, :update?
    return require_vault_unlock if selected_vault_item_ids.any? && !touch_privacy_vault_lease!

    BackupPlans::Generate.call(
      actor: current_user,
      event_plan: @event_plan,
      scenario: backup_plan_params[:scenario],
      private_note_ids: selected_private_note_ids,
      vault_item_ids: selected_vault_item_ids,
      vault_lease: privacy_vault_lease,
      locale: I18n.locale
    )
    redirect_to workspace_path, notice: t("event_plans.backup_plans.generate.notice")
  rescue EventPlans::VaultAccessError
    require_vault_unlock
  rescue EventPlans::GenerationSupersededError
    redirect_to workspace_path, alert: t("event_plans.backup_plans.generate.superseded")
  rescue EventPlans::GenerationError, ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("event_plans.backup_plans.generate.error")
  end

  def promote
    authorize @event_plan, :update?
    backup_option = @backup_plan.backup_options.find(params[:option_id])
    needs_vault_access = @backup_plan.include_vault_context? && !already_promoted?(backup_option)
    return require_vault_unlock if needs_vault_access && !touch_privacy_vault_lease!

    BackupPlans::Promote.call(actor: current_user, backup_option:, vault_lease: privacy_vault_lease)
    redirect_to workspace_path, notice: t("event_plans.backup_plans.promote.notice")
  rescue BackupPlans::PromotionUnavailableError, ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("event_plans.backup_plans.promote.unavailable")
  end

  private

  def set_event_plan
    @event_plan = policy_scope(EventPlan).for_active_relationships.visible.find(params[:event_plan_id])
  end

  def set_backup_plan
    @backup_plan = @event_plan.backup_plans.find(params[:id])
  end

  def backup_plan_params
    params.fetch(:backup_plan, ActionController::Parameters.new).permit(
      :scenario,
      private_note_ids: [],
      vault_item_ids: []
    )
  end

  def selected_private_note_ids
    Array(backup_plan_params[:private_note_ids]).compact_blank.map(&:to_s).uniq.first(EventPlans::ContextBuilder::MAX_PER_KIND)
  end

  def selected_vault_item_ids
    Array(backup_plan_params[:vault_item_ids]).compact_blank.map(&:to_s).uniq.first(EventPlans::ContextBuilder::MAX_PER_KIND)
  end

  def require_vault_unlock
    redirect_to relationship_profile_privacy_vault_path(@event_plan.relationship_profile),
      alert: t("privacy_vaults.access_required")
  end

  def already_promoted?(backup_option)
    @backup_plan.promoted? && backup_option.promoted_at.present?
  end

  def workspace_path
    event_plan_path(@event_plan, anchor: "backup-options")
  end
end
