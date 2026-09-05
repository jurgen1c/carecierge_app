class ExternalProviderActionsController < ApplicationController
  before_action :set_profile, only: %i[index new create]
  before_action :set_record, only: %i[edit update destroy]
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def index
    authorize @relationship_profile, :show?
    @pagy, @records = pagy(:offset, policy_scope(ExternalProviderAction)
      .where(relationship_profile: @relationship_profile).recent_first.includes(:relationship_profile, :event_plan, :booking, :reminder, gift_purchase_plan: :gift, vendor_quote: :vendor), limit: 20)
  end

  def new
    @record = current_user.external_provider_actions.new(relationship_profile: @relationship_profile)
    authorize @record
  end

  def create
    @record = current_user.external_provider_actions.new(relationship_profile: @relationship_profile)
    authorize @record
    ExternalProviderActions::Save.call(@record, actor: current_user, attributes: record_attributes.except(:lock_version))
    redirect_to history_path, notice: t("external_provider_actions.saved")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def edit
    authorize @record
  end

  def update
    authorize @record
    attributes = record_attributes
    version = Integer(attributes.delete(:lock_version), 10)
    ExternalProviderActions::Save.call(@record, actor: current_user, attributes:, expected_lock_version: version)
    redirect_to history_path, notice: t("external_provider_actions.saved")
  rescue ActiveRecord::StaleObjectError
    redirect_to history_path, alert: t("external_provider_actions.changed")
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_content
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "Invalid lock version"
  end

  def destroy
    authorize @record
    ExternalProviderActions::Destroy.call(@record, actor: current_user)
    redirect_to history_path, notice: t("external_provider_actions.deleted")
  end

  private

  def set_profile
    @relationship_profile = policy_scope(RelationshipProfile).friendly.find(params[:relationship_profile_id])
  end

  def set_record
    @record = policy_scope(ExternalProviderAction).find(params[:id])
    @relationship_profile = @record.relationship_profile
  end

  def history_path = relationship_profile_external_provider_actions_path(@relationship_profile)

  def record_attributes
    attributes = params.require(:external_provider_action).permit(
      :provider_name, :provider_kind, :action_kind, :status, :source_label, :source_url,
      :external_reference, :failure_details, :lock_version,
      *ExternalProviderAction::CONTEXTS.map { |context| "#{context}_id" }
    ).to_h.symbolize_keys
    ExternalProviderAction::CONTEXTS.each do |context|
      key = :"#{context}_id"
      next unless attributes[key].present?

      attributes[key] = ExternalProviderAction.context_scope(@relationship_profile, context).find(attributes[key]).id
    end
    attributes
  end
end
