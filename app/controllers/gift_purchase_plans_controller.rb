class GiftPurchasePlansController < ApplicationController
  before_action :set_gift
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def show
    @purchase_plan = @gift.purchase_plan || @gift.build_purchase_plan(options: draft_options)
    prepare_workspace
  end

  def update
    attributes = purchase_params.to_h.symbolize_keys
    expected_version = attributes.delete(:lock_version)
    raise ActionController::BadRequest if expected_version.blank?

    @purchase_plan = GiftPurchasePlans::Save.call(gift: @gift, attributes:, expected_version:)
    redirect_to workspace_path, notice: t("gift_purchase_plans.saved")
  rescue ActiveRecord::RecordInvalid => error
    @purchase_plan = error.record
    prepare_workspace
    render :show, status: :unprocessable_content
  rescue ActiveRecord::StaleObjectError
    redirect_to workspace_path, alert: t("gift_purchase_plans.changed")
  end

  def task
    event_plan = current_user.event_plans.where(relationship_profile: @relationship_profile).find(params[:event_plan_id])
    task = GiftPurchasePlans::AddTask.call(gift: @gift, event_plan:)
    redirect_to event_plan_path(task.event_plan), notice: t("gift_purchase_plans.task_added")
  end

  private

  def set_gift
    @relationship_profile = current_user.relationship_profiles.active.friendly.find(params[:relationship_profile_id])
    @gift = @relationship_profile.gifts.find(params[:gift_id])
    authorize @gift, :update?
    response.headers["Cache-Control"] = "no-store"
  end

  def prepare_workspace
    @event_plans = current_user.event_plans.where(relationship_profile: @relationship_profile, status: "active").order(created_at: :desc, id: :desc)
  end

  def draft_options
    return [] if @gift.vendor.blank?

    [ { "vendor" => @gift.vendor.truncate(200), "cost" => @gift.price.to_s, "constraints_checked" => "0" } ]
  end

  def workspace_path = relationship_profile_gift_purchase_plan_path(@relationship_profile, @gift)

  def purchase_params
    params.require(:gift_purchase_plan).permit(
      :budget, :currency, :purchase_by, :expected_delivery_on, :follow_up_on,
      :purchase_status, :delivery_status, :shipping_notes, :constraints, :follow_up_notes, :lock_version,
      options: [ :vendor, :url, :cost, :constraints_checked ]
    )
  end
end
