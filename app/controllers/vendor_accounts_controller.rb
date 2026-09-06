class VendorAccountsController < ApplicationController
  before_action :set_account, except: :create
  before_action -> { response.headers["Cache-Control"] = "no-store" }
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
  rescue_from ActiveRecord::StaleObjectError, with: :stale

  def show
    authorize @account, @account.persisted? ? :show? : :create?
    prepare_history
  end

  def create
    authorize VendorAccount
    VendorAccounts::Enroll.call(user: current_user)
    redirect_to vendor_account_path, notice: t("vendor_accounts.enrolled")
  end

  def update
    authorize @account
    VendorAccounts::Save.call(user: current_user, account: @account, attributes: profile_params.to_h.symbolize_keys,
      version: params.dig(:vendor_account, :lock_version))
    redirect_to vendor_account_path, notice: t("vendor_accounts.saved")
  rescue ActiveRecord::RecordInvalid
    @account.status = @account.status_in_database
    prepare_history
    render :show, status: :unprocessable_content
  end

  def submit
    authorize @account
    VendorAccounts::Transition.call(user: current_user, account: @account, to: "submitted", version: params[:version])
    redirect_to vendor_account_path, notice: t("vendor_accounts.submitted")
  rescue ActiveRecord::RecordInvalid => error
    errors = error.record.errors.map { |entry| [ entry.attribute, entry.message ] }
    @account.reload
    errors.each { |attribute, message| @account.errors.add(attribute, message) }
    prepare_history
    render :show, status: :unprocessable_content
  end

  private

  def set_account
    @account = policy_scope(VendorAccount).find_by(user: current_user)
    @account ||= VendorAccount.new(user: current_user) if action_name == "show"
    raise ActiveRecord::RecordNotFound unless @account
  end

  def profile_params
    permitted = params.require(:vendor_account).permit(:business_name, :service_area, :offerings,
      :contact_channels, :source_url, :provenance, categories: [])
    permitted[:categories] = permitted[:categories].reject(&:blank?) if permitted[:categories]
    permitted
  end

  def prepare_history
    @pagy, @reviews = pagy(:offset, @account.reviews.order(created_at: :desc, id: :desc), limit: 20)
  end

  def stale
    redirect_to vendor_account_path, alert: t("vendor_accounts.stale"), status: :see_other
  end
end
