class TimelineEntriesController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_timeline_type
  before_action :set_timeline_entry, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @timeline_entry = @relationship_profile.timeline_entries.new(
      entry_type: @timeline_type.presence || "note",
      occurred_at: Time.current
    )
    authorize @timeline_entry
  end

  def edit
  end

  def create
    @timeline_entry = @relationship_profile.timeline_entries.new(timeline_entry_params)
    @timeline_entry.origin = "manual"
    authorize @timeline_entry

    if @timeline_entry.save
      refresh_timeline_entries(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    @timeline_entry.assign_attributes(timeline_entry_params)

    if @timeline_entry.save
      refresh_timeline_entries(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def destroy
    @timeline_entry.destroy!

    refresh_timeline_entries(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .friendly
      .find(params[:relationship_profile_id])
  end

  def set_timeline_type
    @timeline_type = params[:timeline_type].to_s.in?(TimelineEntry::ENTRY_TYPES) ? params[:timeline_type].to_s : nil
  end

  def set_timeline_entry
    @timeline_entry = @relationship_profile.timeline_entries.find(params[:id])
    authorize @timeline_entry
  end

  def timeline_entry_params
    params.require(:timeline_entry).permit(:entry_type, :title, :body, :occurred_at)
  end

  def refresh_timeline_entries(message, alert: false, status: :ok)
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
          action == :edit ? helpers.dom_id(@timeline_entry) : "new_timeline_entry",
          partial: "timeline_entries/form_frame",
          locals: { relationship_profile: @relationship_profile, timeline_entry: @timeline_entry, timeline_type: @timeline_type }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
