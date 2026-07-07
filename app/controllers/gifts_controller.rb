class GiftsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_gift, only: %i[edit update mark_given destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @gift = @relationship_profile.gifts.new
    authorize @gift
  end

  def edit
  end

  def create
    @gift = @relationship_profile.gifts.new(gift_params)
    authorize @gift

    if @gift.save
      refresh_gifts(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    if @gift.update(gift_params)
      refresh_gifts(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def mark_given
    result_params = gift_result_params
    @gift.mark_given!(
      given_on: result_params[:given_on].presence || Date.current,
      reaction: result_params[:reaction],
      outcome: result_params[:outcome]
    )

    refresh_gifts(t(".notice"))
  rescue ActiveRecord::RecordInvalid
    @gift.reload
    refresh_gifts(t(".error"), alert: true, status: :unprocessable_entity)
  end

  def destroy
    @gift.destroy!

    refresh_gifts(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .includes(:gifts)
      .friendly
      .find(params[:relationship_profile_id])
  end

  def set_gift
    @gift = @relationship_profile.gifts.find(params[:id])
    authorize @gift
  end

  def gift_params
    permitted_params = params.require(:gift).permit(:name, :status, :occasion, :price, :vendor, :given_on, :reaction, :outcome, :notes)
    permitted_params.delete(:status) if permitted_params[:status].present? && !editable_status_param?(permitted_params[:status])
    permitted_params.delete(:given_on)
    permitted_params.delete(:reaction)
    permitted_params.delete(:outcome)
    permitted_params
  end

  def editable_status_param?(status)
    status.in?(Gift::EDITABLE_STATUSES) && (@gift.blank? || @gift.status.in?(Gift::EDITABLE_STATUSES))
  end

  def gift_result_params
    permitted_params = params.fetch(:gift_result, ActionController::Parameters.new).permit(:given_on, :reaction, :outcome)
    permitted_params.delete(:outcome) if permitted_params[:outcome].present? && !permitted_params[:outcome].in?(Gift::OUTCOMES)
    permitted_params
  end

  def refresh_gifts(message, alert: false, status: :ok)
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
          action == :edit ? helpers.dom_id(@gift) : "new_gift",
          partial: "gifts/form_frame",
          locals: { relationship_profile: @relationship_profile, gift: @gift }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
