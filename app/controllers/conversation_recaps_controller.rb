class ConversationRecapsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_timeline_type
  before_action :set_conversation_recap, only: %i[edit update destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @conversation_recap = @relationship_profile.conversation_recaps.new(occurred_at: Time.current)
    authorize @conversation_recap
  end

  def edit
  end

  def create
    @conversation_recap = @relationship_profile.conversation_recaps.new(conversation_recap_params)
    authorize @conversation_recap

    if save_conversation_recap
      refresh_conversation_recaps(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    @conversation_recap.assign_attributes(conversation_recap_params)

    if save_conversation_recap
      refresh_conversation_recaps(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def destroy
    @conversation_recap.destroy!

    refresh_conversation_recaps(t(".notice"))
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

  def set_conversation_recap
    @conversation_recap = @relationship_profile.conversation_recaps.find(params[:id])
    authorize @conversation_recap
  end

  def conversation_recap_params
    params.require(:conversation_recap).permit(:title, :body, :occurred_at, :capture_source, :transcript, :request_memory_extraction)
  end

  def save_conversation_recap
    ConversationRecap.transaction do
      @conversation_recap.save!
      sync_timeline_entry!
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def sync_timeline_entry!
    timeline_entry = @conversation_recap.timeline_entry || @relationship_profile.timeline_entries.build(source_record: @conversation_recap)
    timeline_entry.assign_attributes(
      entry_type: "conversation_recap",
      origin: "system",
      title: @conversation_recap.title,
      body: @conversation_recap.body,
      occurred_at: @conversation_recap.occurred_at
    )
    timeline_entry.save!
  end

  def refresh_conversation_recaps(message, alert: false, status: :ok)
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
          action == :edit ? helpers.dom_id(@conversation_recap) : "new_conversation_recap",
          partial: "conversation_recaps/form_frame",
          locals: { relationship_profile: @relationship_profile, conversation_recap: @conversation_recap, selected_type: @timeline_type }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
