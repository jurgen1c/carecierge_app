class CommitmentsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_timeline_type
  before_action :set_commitment, only: %i[edit update destroy complete cancel reopen]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @commitment = @relationship_profile.commitments.new
    authorize @commitment
  end

  def edit
  end

  def create
    @commitment = @relationship_profile.commitments.new
    authorize @commitment

    if Commitments::Save.call(@commitment, attributes: commitment_params.merge(status: "open"))
      refresh_commitments(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    if Commitments::Save.call(@commitment, attributes: commitment_params)
      refresh_commitments(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def destroy
    @commitment.destroy!
    refresh_commitments(t(".notice"))
  end

  %i[complete cancel reopen].each do |event|
    define_method(event) do
      if Commitments::Save.call(@commitment, event:)
        refresh_commitments(t(".notice"))
      else
        refresh_commitments(t(".error"), alert: true, status: :unprocessable_entity)
      end
    end
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .includes(commitments: :reminders)
      .friendly
      .find(params[:relationship_profile_id])
  end

  def set_timeline_type
    @timeline_type = params[:timeline_type].to_s.in?(TimelineEntry::ENTRY_TYPES) ? params[:timeline_type].to_s : nil
  end

  def set_commitment
    @commitment = @relationship_profile.commitments.find(params[:id])
    authorize @commitment
  end

  def commitment_params
    params.require(:commitment).permit(:title, :notes, :due_on)
  end

  def refresh_commitments(message, alert: false, status: :ok)
    flash.now[alert ? :alert : :notice] = message
    @relationship_profile.reload
    @relationship_profile.commitments.includes(:reminders).load

    respond_to do |format|
      format.turbo_stream { render :refresh, status: }
      format.html do
        redirect_to relationship_profile_path(@relationship_profile, timeline_type: @timeline_type),
          notice: alert ? nil : message,
          alert: alert ? message : nil
      end
    end
  end

  def render_form(action, status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          action == :edit ? helpers.dom_id(@commitment) : "new_commitment",
          partial: "commitments/form_frame",
          locals: { relationship_profile: @relationship_profile, commitment: @commitment, selected_type: @timeline_type }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
