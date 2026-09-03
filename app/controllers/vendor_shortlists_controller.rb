class VendorShortlistsController < ApplicationController
  before_action :set_vendor_shortlist, only: :show

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    authorize VendorShortlist
    @pagy, @vendor_shortlists = pagy(
      :offset,
      policy_scope(VendorShortlist)
      .recent_first
      .includes(:relationship_profile, :event_plan, vendor_options: :vendor),
      limit: 20
    )
  end

  def new
    @vendor_shortlist = current_user.vendor_shortlists.new
    if params[:event_plan_id].present?
      @vendor_shortlist.event_plan = active_event_plans.find(params[:event_plan_id])
      @vendor_shortlist.relationship_profile = @vendor_shortlist.event_plan.relationship_profile
    elsif params[:relationship_profile_id].present?
      @vendor_shortlist.relationship_profile = active_relationship_profiles.find(params[:relationship_profile_id])
    end
    authorize @vendor_shortlist
    prepare_form
  end

  def create
    event_plan = active_event_plans.find(shortlist_params[:event_plan_id]) if shortlist_params[:event_plan_id].present?
    relationship_profile = if event_plan
      event_plan.relationship_profile
    elsif shortlist_params[:relationship_profile_id].present?
      active_relationship_profiles.find(shortlist_params[:relationship_profile_id])
    end
    @vendor_shortlist = current_user.vendor_shortlists.new(
      title: shortlist_params[:title],
      event_plan:,
      relationship_profile:
    )
    authorize @vendor_shortlist
    @selected_vendor_ids = submitted_vendor_ids
    vendors = requested_vendors
    @vendor_shortlist = VendorShortlists::Create.call(
      user: current_user,
      attributes: { title: shortlist_params[:title], event_plan:, relationship_profile: },
      vendors:
    )

    redirect_to @vendor_shortlist, notice: t("vendor_shortlists.create.notice")
  rescue ActiveRecord::RecordInvalid => error
    @vendor_shortlist = error.record.is_a?(VendorShortlist) ? error.record : @vendor_shortlist
    prepare_form
    render :new, status: :unprocessable_content
  end

  def show
    authorize @vendor_shortlist
    @options = @vendor_shortlist.vendor_options.includes(:vendor).to_a
    @available_vendors = policy_scope(Vendor).where.not(id: @options.map(&:vendor_id)).ordered
    @editable = policy(@vendor_shortlist).update?
    @removable = policy(@vendor_shortlist).remove_options?
  end

  private

  def set_vendor_shortlist
    @vendor_shortlist = policy_scope(VendorShortlist).find(params[:id])
  end

  def shortlist_params
    params.require(:vendor_shortlist).permit(:title, :relationship_profile_id, :event_plan_id, vendor_ids: [])
  end

  def requested_vendors
    if @selected_vendor_ids.length > VendorShortlist::MAX_OPTIONS
      @vendor_shortlist.errors.add(:vendor_options, :too_many, count: VendorShortlist::MAX_OPTIONS)
      raise ActiveRecord::RecordInvalid, @vendor_shortlist
    end

    records = policy_scope(Vendor).where(id: @selected_vendor_ids).to_a
    raise ActiveRecord::RecordNotFound unless records.length == @selected_vendor_ids.length

    records
  end

  def submitted_vendor_ids
    Array(shortlist_params[:vendor_ids]).compact_blank.uniq
  end

  def active_relationship_profiles
    policy_scope(RelationshipProfile).active
  end

  def active_event_plans
    policy_scope(EventPlan).for_active_relationships.where(status: "active")
  end

  def prepare_form
    @selected_vendor_ids ||= @vendor_shortlist.vendor_ids
    @relationship_profiles = active_relationship_profiles.ordered
    @event_plans = active_event_plans.ordered.includes(:relationship_profile)
    @vendors = policy_scope(Vendor).ordered
  end

  def not_found = head(:not_found)
end
