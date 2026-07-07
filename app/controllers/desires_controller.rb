class DesiresController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_desire, only: %i[edit update fulfill destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @desire = @relationship_profile.desires.new
    authorize @desire
  end

  def edit
  end

  def create
    @desire = @relationship_profile.desires.new(desire_params.merge(source: "manual"))
    authorize @desire

    if @desire.save
      refresh_desires(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    if @desire.update(desire_params)
      refresh_desires(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def fulfill
    fulfillment_params = desire_fulfillment_params
    @desire.fulfill!(
      fulfilled_on: fulfillment_params[:fulfilled_on].presence || Date.current,
      notes: fulfillment_params[:notes]
    )

    refresh_desires(t(".notice"))
  rescue ActiveRecord::RecordInvalid
    @desire.reload
    refresh_desires(t(".error"), alert: true, status: :unprocessable_entity)
  end

  def destroy
    @desire.destroy!

    refresh_desires(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .includes(desires: :fulfillments)
      .friendly
      .find(params[:relationship_profile_id])
  end

  def set_desire
    @desire = @relationship_profile.desires.find(params[:id])
    authorize @desire
  end

  def desire_params
    permitted_params = params.require(:desire).permit(:title, :category, :status, :captured_on, :notes)
    permitted_params.delete(:status) if permitted_params[:status].present? && !editable_status_param?(permitted_params[:status])
    permitted_params
  end

  def editable_status_param?(status)
    status.in?(Desire::EDITABLE_STATUSES) && (@desire.blank? || @desire.status.in?(Desire::EDITABLE_STATUSES))
  end

  def desire_fulfillment_params
    params.fetch(:desire_fulfillment, {}).permit(:fulfilled_on, :notes)
  end

  def refresh_desires(message, alert: false, status: :ok)
    flash.now[alert ? :alert : :notice] = message
    @relationship_profile.reload

    respond_to do |format|
      format.turbo_stream { render :refresh, status: }
      format.html { redirect_to relationship_profile_path(@relationship_profile), notice: alert ? nil : message, alert: alert ? message : nil }
    end
  end

  def render_form(action, status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          action == :edit ? helpers.dom_id(@desire) : "new_desire",
          partial: "desires/form_frame",
          locals: { relationship_profile: @relationship_profile, desire: @desire }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
