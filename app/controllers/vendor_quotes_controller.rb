class VendorQuotesController < ApplicationController
  before_action :set_event_plan, only: %i[new create]
  before_action :set_vendor_quote, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    return prepare_history unless params[:event_plan_id]

    set_event_plan
    quote = current_user.vendor_quotes.new(event_plan: @event_plan)
    authorize quote
    @quotes = policy_scope(VendorQuote).where(event_plan: @event_plan).ordered.includes(:vendor).to_a
    @as_of = OwnerLocalCalendar.date_for(user: current_user)
    @editable = @event_plan.active? && @event_plan.relationship_profile.kept?
  end

  def new
    @vendor_quote = current_user.vendor_quotes.new(event_plan: @event_plan, vendor_id: params[:vendor_id])
    authorize @vendor_quote
    prepare_form
  end

  def create
    vendor = policy_scope(Vendor).find(vendor_quote_params[:vendor_id])
    @vendor_quote = current_user.vendor_quotes.new(
      vendor_quote_params.except(:vendor_id, :lock_version).merge(event_plan: @event_plan, vendor:)
    )
    authorize @vendor_quote
    @vendor_quote.save_with_context_lock!

    redirect_to event_plan_vendor_quotes_path(@event_plan), notice: t("vendor_quotes.create.notice")
  rescue ActiveRecord::RecordInvalid
    prepare_form
    render :new, status: :unprocessable_content
  end

  def edit
    authorize @vendor_quote
    @event_plan = @vendor_quote.event_plan
    prepare_form
  end

  def update
    authorize @vendor_quote
    attributes = vendor_quote_params
    @vendor_quote.update_details!(attributes, expected_lock_version: attributes.fetch(:lock_version))

    redirect_to event_plan_vendor_quotes_path(@vendor_quote.event_plan), notice: t("vendor_quotes.update.notice")
  rescue ActiveRecord::StaleObjectError
    redirect_to event_plan_vendor_quotes_path(@vendor_quote.event_plan), alert: t("vendor_quotes.update.changed")
  rescue ActiveRecord::RecordInvalid
    @event_plan = @vendor_quote.event_plan
    prepare_form
    render :edit, status: :unprocessable_content
  end

  def destroy
    authorize @vendor_quote
    event_plan = @vendor_quote.event_plan
    @vendor_quote.remove!

    redirect_to event_plan_vendor_quotes_path(event_plan), notice: t("vendor_quotes.destroy.notice")
  end

  private

  def set_event_plan
    @event_plan = policy_scope(EventPlan).find(params[:event_plan_id])
  end

  def set_vendor_quote
    @vendor_quote = policy_scope(VendorQuote).find(params[:id])
  end

  def prepare_form
    @vendors = policy_scope(Vendor).ordered
  end

  def prepare_history
    authorize VendorQuote
    @pagy, quotes = pagy(
      :offset,
      policy_scope(VendorQuote).ordered.includes(:vendor, event_plan: :relationship_profile),
      limit: 20
    )
    @quote_groups = quotes.group_by(&:event_plan)
  end

  def vendor_quote_params
    fields = %i[amount currency scope_details expires_on decision_due_on status next_action notes lock_version]
    fields << :vendor_id if action_name == "create"
    permitted = params.require(:vendor_quote).permit(*fields)
    permitted[:lock_version] = Integer(permitted.require(:lock_version), 10) if action_name == "update"
    permitted
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "Invalid lock version"
  end

  def not_found = head(:not_found)
end
