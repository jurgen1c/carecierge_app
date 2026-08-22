class EventPlansController < ApplicationController
  include PrivacyVaultSession

  MAX_BUDGET_INPUT_LENGTH = 40

  rate_limit to: 6, within: 1.minute, by: -> { current_user.id }, only: :suggest

  before_action :set_event_plan, except: %i[index new create]

  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def index
    authorize EventPlan
    @event_plans = event_plan_scope.includes(:relationship_profile).to_a
  end

  def show
    prepare_workspace
  end

  def new
    relationship_profile = selected_relationship_profile
    @event_plan = current_user.event_plans.new(relationship_profile:)
    authorize @event_plan
    prepare_form_options
  end

  def create
    relationship_profile = current_user.relationship_profiles.active.find(event_plan_params[:relationship_profile_id])
    @event_plan = current_user.event_plans.new(relationship_profile:)
    authorize @event_plan
    @event_plan = EventPlans::Create.call(
      user: current_user,
      relationship_profile:,
      attributes: plan_attributes,
      locale: I18n.locale
    )
    redirect_to event_plan_path(@event_plan), notice: t("event_plans.create.notice")
  rescue ActiveRecord::RecordInvalid => error
    @event_plan = error.record.is_a?(EventPlan) ? error.record : @event_plan
    prepare_form_options
    render :new, status: :unprocessable_content
  end

  def edit
    prepare_form_options
  end

  def update
    EventPlans::Update.call(event_plan: @event_plan, attributes: plan_attributes)
    redirect_to event_plan_path(@event_plan), notice: t("event_plans.update.notice")
  rescue ActiveRecord::RecordInvalid
    prepare_form_options
    render :edit, status: :unprocessable_content
  end

  def archive
    transition_plan(:archive!, destination: event_plans_path, notice: "event_plans.archive.notice")
  end

  def complete
    transition_plan(:complete!, destination: event_plan_path(@event_plan), notice: "event_plans.complete.notice")
  end

  def reopen
    transition_plan(:reopen!, destination: event_plan_path(@event_plan), notice: "event_plans.reopen.notice")
  end

  def suggest
    return require_vault_unlock if selected_vault_item_ids.any? && !touch_privacy_vault_lease!

    EventPlans::Suggest.call(
      actor: current_user,
      event_plan: @event_plan,
      private_note_ids: selected_private_note_ids,
      vault_item_ids: selected_vault_item_ids,
      vault_lease: privacy_vault_lease,
      locale: I18n.locale
    )
    redirect_to event_plan_path(@event_plan), notice: t("event_plans.suggest.notice")
  rescue EventPlans::VaultAccessError
    require_vault_unlock
  rescue EventPlans::GenerationSupersededError
    render_suggestion_error("event_plans.suggest.superseded")
  rescue EventPlans::GenerationError, ActiveRecord::RecordInvalid
    render_suggestion_error("event_plans.suggest.error")
  end

  private

  def set_event_plan
    scope = policy_scope(EventPlan).for_active_relationships
    scope = scope.visible unless action_name == "archive"
    @event_plan = scope.find(params[:id])
    authorize @event_plan
  end

  def event_plan_scope
    policy_scope(EventPlan).for_active_relationships.visible.ordered
  end

  def selected_relationship_profile
    return if params[:relationship_profile_id].blank?

    current_user.relationship_profiles.active.find(params[:relationship_profile_id])
  end

  def event_plan_params
    params.require(:event_plan).permit(
      :relationship_profile_id,
      :title,
      :occasion_type,
      :starts_on,
      :budget,
      :guest_list,
      :notes
    )
  end

  def plan_attributes
    attributes = event_plan_params.except(:relationship_profile_id, :budget)
    return attributes unless event_plan_params.key?(:budget)

    attributes.merge(budget_cents: budget_cents)
  end

  def budget_cents
    raw_budget = event_plan_params[:budget].to_s
    @budget_input = raw_budget
    return if raw_budget.blank?
    return -1 if raw_budget.length > MAX_BUDGET_INPUT_LENGTH

    decimal = BigDecimal(raw_budget, exception: false)
    maximum = BigDecimal(EventPlan::MAX_BUDGET_CENTS.to_s) / 100
    return -1 unless decimal&.finite? && decimal.between?(0, maximum)

    (decimal * 100).round
  rescue ArgumentError, FloatDomainError
    -1
  end

  def suggestion_params
    params.fetch(:event_plan_suggestion, ActionController::Parameters.new).permit(
      private_note_ids: [],
      vault_item_ids: []
    )
  end

  def selected_private_note_ids
    Array(suggestion_params[:private_note_ids]).compact_blank.map(&:to_s).uniq.first(EventPlans::ContextBuilder::MAX_PER_KIND)
  end

  def selected_vault_item_ids
    Array(suggestion_params[:vault_item_ids]).compact_blank.map(&:to_s).uniq.first(EventPlans::ContextBuilder::MAX_PER_KIND)
  end

  def prepare_workspace
    @event_plans = event_plan_scope.includes(:relationship_profile).to_a
    @plan_task ||= PlanTask.new
    @private_notes = @event_plan.relationship_profile.relationship_notes
      .where(private: true)
      .where.missing(:privacy_vault_item)
      .with_rich_text_body
      .order(created_at: :desc, id: :desc)
      .limit(EventPlans::ContextBuilder::MAX_PER_KIND)
      .to_a
    @vault_items = @event_plan.relationship_profile.privacy_vault_items
      .suggestion_allowed
      .ordered
      .limit(EventPlans::ContextBuilder::MAX_PER_KIND)
      .to_a
    @vault_unlocked = privacy_vault_unlocked?
    @next_reminder = @event_plan.reminders.active.by_effective_delivery.first
  end

  def prepare_form_options
    @relationship_profiles = current_user.relationship_profiles.active.ordered
  end

  def require_vault_unlock
    redirect_to relationship_profile_privacy_vault_path(@event_plan.relationship_profile), alert: t("privacy_vaults.access_required")
  end

  def render_suggestion_error(key)
    prepare_workspace
    flash.now[:alert] = t(key)
    render :show, status: :unprocessable_content
  end

  def transition_plan(event, destination:, notice:)
    @event_plan.public_send(event)
    redirect_to destination, notice: t(notice)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
    redirect_to event_plans_path, alert: t("event_plans.lifecycle.unavailable")
  end
end
