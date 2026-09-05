class MarketplaceListingsController < ApplicationController
  before_action :set_listing, only: %i[show save use]
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def index
    authorize MarketplaceListing
    prepare_catalog
  end

  def compare
    authorize MarketplaceListing
    ids = Array(params[:listing_ids]).map(&:to_s).compact_blank.uniq
    unless ids.length.between?(1, MarketplaceListing::MAX_COMPARISON)
      @selected_listing_ids = ids.first(20)
      flash.now[:alert] = t("marketplace.invalid_selection")
      scope = policy_scope(MarketplaceListing)
      scope = scope.where(id: @selected_listing_ids) if @selected_listing_ids.any?
      prepare_catalog(scope:)
      render :index, status: :unprocessable_content
      return
    end

    @listings = policy_scope(MarketplaceListing).where(id: ids).ordered.to_a
    raise ActiveRecord::RecordNotFound unless @listings.length == ids.length
  end

  def show
    @vendor = policy_scope(Vendor).find_by(marketplace_listing: @listing)
    if @vendor
      @event_plans = policy_scope(EventPlan).for_active_relationships.where(status: "active").ordered
      @relationships = policy_scope(RelationshipProfile).active.ordered
    end
  end

  def save
    MarketplaceListings::Save.call(user: current_user, listing: @listing)
    redirect_to @listing, notice: t("marketplace.saved")
  end

  def use
    vendor = policy_scope(Vendor).find_by!(marketplace_listing: @listing)
    authorize vendor, :show?
    case params[:destination]
    when "plan", "booking"
      plan = policy_scope(EventPlan).for_active_relationships.where(status: "active").find(params[:event_plan_id])
      authorize plan, :update?
      redirect_to params[:destination] == "plan" ? vendors_path(event_plan_id: plan.id, vendor_id: vendor.id) : new_event_plan_booking_path(plan, vendor_id: vendor.id)
    when "gift"
      profile = policy_scope(RelationshipProfile).active.find(params[:relationship_profile_id])
      authorize profile, :update?
      redirect_to new_relationship_profile_gift_path(profile, vendor_id: vendor.id)
    when "shortlist"
      redirect_to new_vendor_shortlist_path(vendor_ids: [ vendor.id ])
    else
      raise ActionController::BadRequest
    end
  end

  private

  def set_listing
    @listing = policy_scope(MarketplaceListing).find(params[:id])
    authorize @listing
    response.headers["Cache-Control"] = "no-store"
  end

  def prepare_catalog(scope: policy_scope(MarketplaceListing))
    @query = scope.ransack(search_params)
    listings = @query.result.ordered
    @occasion = params[:occasion].to_s.presence_in(EventPlan::OCCASION_TYPES)
    listings = listings.for_occasion(@occasion) if @occasion
    @pagy, @listings = pagy(:offset, listings, limit: 20)
  end

  def search_params
    params.fetch(:q, ActionController::Parameters.new).permit(
      :name_or_curated_summary_cont, :service_area_cont, :category_eq, :relationship_use_cases_cont
    ).to_h.transform_values { |value| value.to_s.first(200) }
  end
end
