class GiftRecommendationsController < ApplicationController
  include PrivacyVaultSession
  include RelationshipProfileShowWorkspace

  MAX_BUDGET_INPUT_LENGTH = 40

  rate_limit to: 6, within: 1.minute, by: -> { current_user.id }, only: %i[generate alternative]

  before_action :set_relationship_profile
  before_action :set_recommendation, except: :generate

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def generate
    authorize @relationship_profile, :update?
    return require_vault_unlock if include_vault_context? && !touch_privacy_vault_lease!

    GiftRecommendations::Generate.call(
      actor: current_user,
      relationship_profile: @relationship_profile,
      budget_cents: budget_cents,
      needed_by: recommendation_params[:needed_by],
      occasion: recommendation_params[:occasion],
      allow_repeats: allow_repeats?,
      private_note_ids: selected_private_note_ids,
      vault_item_ids: selected_vault_item_ids,
      vault_lease: privacy_vault_lease,
      explicitly_approved: true,
      locale: I18n.locale
    )

    redirect_to workspace_path, notice: t("gift_recommendations.generate.notice")
  rescue GiftRecommendations::VaultAccessError
    require_vault_unlock
  rescue GiftRecommendations::PermissionDeniedError
    render_generation_error("gift_recommendations.generate.permission_denied")
  rescue GiftRecommendations::GenerationSupersededError
    render_generation_error("gift_recommendations.generate.superseded")
  rescue GiftRecommendations::GenerationError, ActiveRecord::RecordInvalid
    render_generation_error("gift_recommendations.generate.provider_error")
  end

  def alternative
    authorize @recommendation, :update?
    private_note_ids = include_private_notes? ? source_ids_for("private_note") : []
    vault_item_ids = include_vault_context? ? source_ids_for("vault") : []
    return require_vault_unlock if vault_item_ids.any? && !touch_privacy_vault_lease!

    GiftRecommendations::Generate.call(
      actor: current_user,
      relationship_profile: @relationship_profile,
      budget_cents: @recommendation.budget_cents,
      needed_by: @recommendation.needed_by,
      occasion: @recommendation.occasion,
      allow_repeats: @recommendation.allow_repeats,
      private_note_ids:,
      vault_item_ids:,
      vault_lease: privacy_vault_lease,
      explicitly_approved: true,
      locale: I18n.locale,
      replace: @recommendation
    )

    redirect_to workspace_path, notice: t("gift_recommendations.alternative.notice")
  rescue GiftRecommendations::VaultAccessError
    require_vault_unlock
  rescue GiftRecommendations::PermissionDeniedError
    redirect_to workspace_path, alert: t("gift_recommendations.generate.permission_denied")
  rescue GiftRecommendations::GenerationError, GiftRecommendations::GenerationSupersededError, ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("gift_recommendations.alternative.error")
  end

  def save
    transition("save", "gift_recommendations.save.notice")
  end

  def dismiss
    transition("dismiss", "gift_recommendations.dismiss.notice")
  end

  def purchase
    transition("purchase", "gift_recommendations.purchase.notice")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.kept.friendly.find(params[:relationship_profile_id])
  end

  def set_recommendation
    @recommendation = @relationship_profile.gift_recommendations.find(params[:id])
  end

  def recommendation_params
    params.fetch(:gift_recommendation, ActionController::Parameters.new).permit(
      :budget,
      :needed_by,
      :occasion,
      :allow_repeats,
      :include_private_notes,
      :include_vault_context
    )
  end

  def budget_cents
    raw_budget = recommendation_params[:budget].to_s
    return if raw_budget.blank?
    return -1 if raw_budget.length > MAX_BUDGET_INPUT_LENGTH

    decimal = BigDecimal(raw_budget, exception: false)
    maximum = BigDecimal(Gift::MAX_PRICE_CENTS.to_s) / 100
    return -1 unless decimal&.finite? && decimal.between?(0, maximum)

    (decimal * 100).round
  rescue ArgumentError, FloatDomainError
    -1
  end

  def allow_repeats?
    boolean_param(:allow_repeats)
  end

  def include_private_notes?
    boolean_param(:include_private_notes)
  end

  def include_vault_context?
    boolean_param(:include_vault_context)
  end

  def boolean_param(key)
    ActiveModel::Type::Boolean.new.cast(recommendation_params[key]) || false
  end

  def selected_private_note_ids
    return [] unless include_private_notes?

    @relationship_profile.relationship_notes
      .where(private: true)
      .where.missing(:privacy_vault_item)
      .order(:created_at, :id)
      .limit(GiftRecommendations::ContextBuilder::MAX_PER_KIND)
      .ids
  end

  def selected_vault_item_ids
    return [] unless include_vault_context?

    @relationship_profile.privacy_vault_items
      .suggestion_allowed
      .ordered
      .limit(GiftRecommendations::ContextBuilder::MAX_PER_KIND)
      .ids
  end

  def source_ids_for(kind)
    prefix = "#{kind}:"
    @recommendation.source_ids.filter_map { |source_id| source_id.delete_prefix(prefix) if source_id.start_with?(prefix) }
  end

  def transition(action, notice_key)
    authorize @recommendation, action == "dismiss" ? :destroy? : :update?
    GiftRecommendations::ApplyAction.call(actor: current_user, recommendation: @recommendation, action:)
    redirect_to workspace_path, notice: t(notice_key)
  rescue ActiveRecord::RecordInvalid
    redirect_to workspace_path, alert: t("gift_recommendations.actions.unavailable")
  end

  def require_vault_unlock
    redirect_to relationship_profile_privacy_vault_path(@relationship_profile), alert: t("privacy_vaults.access_required")
  end

  def workspace_path
    relationship_profile_path(@relationship_profile, anchor: "gift-recommendations")
  end

  def render_generation_error(translation_key)
    @gift_recommendation_form_state = recommendation_params.to_h.symbolize_keys
    prepare_relationship_profile_show
    flash.now[:alert] = t(translation_key)
    render "relationship_profiles/show", status: :unprocessable_content
  end
end
