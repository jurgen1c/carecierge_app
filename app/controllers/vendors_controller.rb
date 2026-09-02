class VendorsController < ApplicationController
  before_action :set_event_plan
  before_action :set_vendor, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    @search = Vendors::SearchQuery.new(policy_scope(Vendor), params: vendor_search_params, event_plan: @event_plan)
    @pagy, @vendors = pagy(:offset, @search.resolve.includes(:event_plan_vendors), limit: 20)
  end

  def new
    @vendor = current_user.vendors.new
    authorize @vendor
  end

  def create
    @vendor = current_user.vendors.new(vendor_params)
    authorize @vendor

    if @event_plan
      EventPlanVendors::Attach.call(event_plan: @event_plan, vendor: @vendor)
    else
      @vendor.save!
    end

    redirect_to vendors_path(event_plan_id: @event_plan&.id), notice: t("vendors.create.notice")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_content
  end

  def edit
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to vendors_path(event_plan_id: @event_plan&.id), notice: t("vendors.update.notice")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @vendor.destroy!
    redirect_to vendors_path(event_plan_id: @event_plan&.id), notice: t("vendors.destroy.notice")
  end

  private

  def set_event_plan
    return if params[:event_plan_id].blank?

    @event_plan = policy_scope(EventPlan).for_active_relationships.where(status: "active").find(params[:event_plan_id])
    authorize @event_plan, action_name == "create" ? :update? : :show?
  end

  def set_vendor
    @vendor = policy_scope(Vendor).find(params[:id])
    authorize @vendor
  end

  def vendor_search_params
    params.fetch(:vendor_search, ActionController::Parameters.new).permit(
      :query, :category, :location, :occasion_type, :preference, :maximum_budget, :timing
    ).to_h
  end

  def vendor_params
    params.require(:vendor).permit(
      :name, :category, :location, :minimum_price, :maximum_price, :availability,
      :occasion_types_text, :preference_tags_text, :fit_notes, :source_kind, :source_name, :source_url,
      occasion_types: []
    )
  end

  def not_found = head(:not_found)
end
