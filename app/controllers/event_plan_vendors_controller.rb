class EventPlanVendorsController < ApplicationController
  before_action :set_event_plan

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def create
    vendor = policy_scope(Vendor).find(params[:vendor_id])
    EventPlanVendors::Attach.call(event_plan: @event_plan, vendor:)

    redirect_to vendors_path(event_plan_id: @event_plan.id), notice: t("vendors.attach.notice")
  end

  def destroy
    assignment = @event_plan.event_plan_vendors.find(params[:id])
    EventPlanVendors::Detach.call(event_plan: @event_plan, assignment:)

    redirect_to vendors_path(event_plan_id: @event_plan.id), notice: t("vendors.detach.notice")
  end

  private

  def set_event_plan
    @event_plan = policy_scope(EventPlan).for_active_relationships.where(status: "active").find(params[:event_plan_id])
    authorize @event_plan, :update?
  end

  def not_found = head(:not_found)
end
