class DataDeletionsController < ApplicationController
  KINDS = %w[ai_generated account].freeze

  rate_limit to: 5, within: 1.minute, by: -> { "#{current_user.id}:#{request.remote_ip}" }

  def create
    authorize :data_control, :create?
    return render_controls_error(t("data_deletions.errors.invalid_request")) unless KINDS.include?(deletion_kind)
    return render_controls_error(t("data_deletions.errors.confirmation")) unless confirmed?
    return render_controls_error(t("data_deletions.errors.password")) if deletion_kind == "account" && !valid_password?

    deletion_kind == "account" ? delete_account : delete_ai_data
  end

  private

  def deletion_params
    @deletion_params ||= params.require(:data_deletion).permit(:kind, :confirmation, :current_password)
  end

  def deletion_kind
    deletion_params[:kind].to_s
  end

  def confirmed?
    ActiveSupport::SecurityUtils.secure_compare(
      deletion_params[:confirmation].to_s,
      current_user.email
    )
  rescue ArgumentError
    false
  end

  def valid_password?
    current_user.valid_password?(deletion_params[:current_password].to_s)
  end

  def delete_ai_data
    DataDeletions::Perform.call(user: current_user, request_kind: "ai_generated") do
      DataDeletions::DeleteAiData.call(user: current_user)
    end

    redirect_to data_control_path, notice: t("data_deletions.ai_generated.notice")
  end

  def delete_account
    user = current_user
    DataDeletions::DeleteAccount.call(user:)
    sign_out(:user)

    redirect_to root_path, notice: t("data_deletions.account.notice")
  rescue DataDeletions::DeleteAccount::ConnectionRevocationError
    render_controls_error(t("data_deletions.errors.connection_revocation"))
  end

  def render_controls_error(message)
    @relationship_profiles = current_user.relationship_profiles.with_discarded.ordered
    flash.now[:alert] = message
    response.headers["Cache-Control"] = "no-store"
    render "data_controls/show", status: :unprocessable_content
  end
end
