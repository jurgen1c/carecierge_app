class ImportantDatesController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_important_date, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @important_date = @relationship_profile.important_dates.new
    authorize @important_date
  end

  def edit
  end

  def create
    @important_date = @relationship_profile.important_dates.new(important_date_params)
    authorize @important_date

    if @important_date.save
      refresh_important_dates(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    if @important_date.update(important_date_params)
      refresh_important_dates(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def destroy
    @important_date.destroy!

    refresh_important_dates(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user.relationship_profiles.includes(:important_dates).friendly.find(params[:relationship_profile_id])
  end

  def set_important_date
    @important_date = @relationship_profile.important_dates.find(params[:id])
    authorize @important_date
  end

  def important_date_params
    params.require(:important_date).permit(
      :date_type,
      :title,
      :starts_on,
      :recurrence,
      :importance_level,
      :reminder_schedule,
      :notes
    )
  end

  def refresh_important_dates(notice)
    flash.now[:notice] = notice
    @important_date = @relationship_profile.important_dates.new
    @relationship_profile.reload

    respond_to do |format|
      format.turbo_stream { render :refresh }
      format.html { redirect_to relationship_profile_path(@relationship_profile), notice: }
    end
  end

  def render_form(action, status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          action == :edit ? helpers.dom_id(@important_date) : "new_important_date",
          partial: "important_dates/form_frame",
          locals: { relationship_profile: @relationship_profile, important_date: @important_date }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
