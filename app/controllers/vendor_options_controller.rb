class VendorOptionsController < ApplicationController
  before_action :set_vendor_shortlist
  before_action :set_vendor_option, except: :create

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :invalid_option

  def create
    vendor = policy_scope(Vendor).find(vendor_option_params[:vendor_id])
    option = @vendor_shortlist.vendor_options.new(vendor:)
    authorize option
    @vendor_shortlist.add_vendor!(vendor)
    redirect_with_notice("add")
  end

  def update
    authorize @vendor_option
    attributes = vendor_option_params
    @vendor_option.update_details!(attributes, expected_lock_version: attributes.fetch(:lock_version))
    redirect_with_notice("update")
  rescue ActiveRecord::StaleObjectError
    redirect_to @vendor_shortlist, alert: t("vendor_shortlists.options.update.changed")
  end

  def favorite
    authorize @vendor_option, :update?
    @vendor_option.toggle_favorite!
    redirect_with_notice("favorite")
  end

  def reject
    authorize @vendor_option, :update?
    @vendor_option.reject!
    redirect_with_notice("reject")
  end

  def select
    authorize @vendor_option, :update?
    @vendor_option.select!
    redirect_with_notice("select")
  end

  def restore
    authorize @vendor_option, :update?
    @vendor_option.restore!
    redirect_with_notice("restore")
  end

  def destroy
    authorize @vendor_option
    @vendor_option.remove!
    redirect_with_notice("remove")
  end

  private

  def set_vendor_shortlist
    @vendor_shortlist = policy_scope(VendorShortlist).find(params[:vendor_shortlist_id])
    raise ActiveRecord::RecordNotFound if action_name != "destroy" && !@vendor_shortlist.mutable?
  end

  def set_vendor_option
    @vendor_option = @vendor_shortlist.vendor_options.find(params[:id])
  end

  def vendor_option_params
    permitted = params.require(:vendor_option).permit(:vendor_id, :notes, :constraints, :next_action, :lock_version)
    permitted[:lock_version] = Integer(permitted.require(:lock_version), 10) if action_name == "update"
    permitted
  rescue ArgumentError, TypeError
    raise ActionController::BadRequest, "Invalid lock version"
  end

  def redirect_with_notice(action)
    redirect_to @vendor_shortlist, notice: t("vendor_shortlists.options.#{action}.notice")
  end

  def invalid_option(error)
    @options = @vendor_shortlist.vendor_options.includes(:vendor).to_a
    if error.record.is_a?(VendorOption) && error.record.persisted?
      index = @options.index { |option| option.id == error.record.id }
      @options[index] = error.record if index
    end
    @available_vendors = policy_scope(Vendor).where.not(id: @options.map(&:vendor_id)).ordered
    @editable = policy(@vendor_shortlist).update?
    @removable = policy(@vendor_shortlist).remove_options?
    @mutation_errors = error.record.errors.full_messages
    render "vendor_shortlists/show", status: :unprocessable_content
  end

  def not_found = head(:not_found)
end
