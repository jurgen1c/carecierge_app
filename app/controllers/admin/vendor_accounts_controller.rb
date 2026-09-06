module Admin
  class VendorAccountsController < ApplicationController
    before_action :authorize_moderator
    before_action :set_account, except: :index
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from ActiveRecord::StaleObjectError, with: :stale

    def index
      @pagy, @accounts = pagy(:offset, VendorAccount.where.not(status: "draft").order(updated_at: :asc, id: :asc), limit: 20)
    end

    def show
      prepare_history
    end

    def update
      @moderation = params.require(:moderation).permit(:decision, :version, :reason)
      VendorAccounts::Transition.call(user: current_user, account: @account, to: @moderation[:decision],
        version: @moderation[:version], reason: @moderation[:reason])
      redirect_to admin_vendor_account_path(@account), notice: t("vendor_accounts.moderated")
    rescue ActiveRecord::RecordInvalid => error
      messages = error.record.errors.full_messages
      @account.reload
      messages.each { |message| @account.errors.add(:base, message) }
      prepare_history
      render :show, status: :unprocessable_content
    end

    private

    def authorize_moderator
      authorize VendorAccount, :moderate?
      response.headers["Cache-Control"] = "no-store"
    end

    def set_account = @account = VendorAccount.find(params[:id])

    def prepare_history
      @pagy, @reviews = pagy(:offset, @account.reviews.order(created_at: :desc, id: :desc), limit: 20)
    end

    def stale
      redirect_to admin_vendor_account_path(@account), alert: t("vendor_accounts.stale"), status: :see_other
    end
  end
end
