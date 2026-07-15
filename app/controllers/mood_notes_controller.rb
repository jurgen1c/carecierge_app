class MoodNotesController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_timeline_type
  before_action :set_mood_note, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @mood_note = @relationship_profile.mood_notes.new(observed_at: Time.current)
    authorize @mood_note
  end

  def edit
  end

  def create
    @mood_note = @relationship_profile.mood_notes.new(mood_note_params)
    authorize @mood_note

    if save_mood_note
      refresh_mood_notes(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    @mood_note.assign_attributes(mood_note_params)

    if save_mood_note
      refresh_mood_notes(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def destroy
    @mood_note.destroy!

    refresh_mood_notes(t(".notice"))
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

  def set_mood_note
    @mood_note = @relationship_profile.mood_notes.find(params[:id])
    authorize @mood_note
  end

  def mood_note_params
    params.require(:mood_note).permit(:category, :observation, :observed_at, :supportive_action, :follow_up_at, :timeline_visible)
  end

  def save_mood_note
    MoodNote.transaction do
      @mood_note.save!
      sync_timeline_entry!
      Interaction.sync_from_source!(@mood_note)
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def sync_timeline_entry!
    unless @mood_note.timeline_visible?
      @mood_note.timeline_entry&.destroy!
      return
    end

    timeline_entry = @mood_note.timeline_entry || @relationship_profile.timeline_entries.build(source_record: @mood_note)
    timeline_entry.assign_attributes(
      entry_type: "mood_note",
      origin: "system",
      title: @mood_note.display_title,
      body: @mood_note.supportive_action,
      occurred_at: @mood_note.observed_at
    )
    timeline_entry.save!
  end

  def refresh_mood_notes(message, alert: false, status: :ok)
    flash.now[alert ? :alert : :notice] = message
    @relationship_profile.reload
    @interactions = @relationship_profile.interactions.includes(:source).ordered.limit(10).to_a

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
          action == :edit ? helpers.dom_id(@mood_note) : "new_mood_note",
          partial: "mood_notes/form_frame",
          locals: { relationship_profile: @relationship_profile, mood_note: @mood_note, selected_type: @timeline_type }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
