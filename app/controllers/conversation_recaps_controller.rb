class ConversationRecapsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_timeline_type
  before_action :set_conversation_recap, only: %i[edit update destroy retry_extraction]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @conversation_recap = @relationship_profile.conversation_recaps.new(occurred_at: Time.current)
    authorize @conversation_recap
    @memory_extraction_enabled = memory_extraction_enabled?
  end

  def edit
    @memory_extraction_enabled = memory_extraction_enabled?
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
    @relationship_profile.with_lock { @conversation_recap.destroy! }

    refresh_conversation_recaps(t(".notice"))
  end

  def retry_extraction
    unless memory_extraction_enabled?
      redirect_to relationship_profile_path(@relationship_profile, anchor: "memory-review"), alert: t(".disabled")
      return
    end

    should_enqueue = @conversation_recap.with_lock do
      next false unless @conversation_recap.extraction_status == "failed"

      @conversation_recap.update!(
        extraction_status: "requested",
        extraction_requested_at: Time.current,
        extraction_started_at: nil,
        extraction_completed_at: nil,
        extraction_error_code: nil
      )
      true
    end
    MemoryExtractionJob.perform_later(@conversation_recap) if should_enqueue

    redirect_to relationship_profile_path(@relationship_profile, anchor: "memory-review"),
      notice: should_enqueue ? t(".notice") : nil,
      alert: should_enqueue ? nil : t(".unavailable")
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
    permitted = params.require(:conversation_recap).permit(:title, :body, :occurred_at, :capture_source, :transcript, :request_memory_extraction)
    permitted.delete(:request_memory_extraction) unless memory_extraction_enabled?
    permitted
  end

  def save_conversation_recap
    extraction_requested = false
    @relationship_profile.with_lock do
      ConversationRecap.transaction do
        @conversation_recap.save!
        extraction_requested = @conversation_recap.saved_change_to_extraction_status?(from: "not_requested", to: "requested")
        sync_timeline_entry!
        Interaction.sync_from_source!(@conversation_recap)
      end
    end
    enqueue_memory_extraction if extraction_requested && memory_extraction_enabled?
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def enqueue_memory_extraction
    MemoryExtractionJob.perform_later(@conversation_recap)
  end

  def memory_extraction_enabled?
    @memory_extraction_enabled ||= FeatureFlag.enabled?("ai_memory_extraction", user: current_user, environment: Rails.env)
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
    @interactions = @relationship_profile.interactions.includes(:source).ordered.limit(10).to_a
    @conversation_recaps = @relationship_profile.conversation_recaps.ordered.includes(:extracted_memories).to_a
    @extracted_memories = @conversation_recaps
      .flat_map(&:extracted_memories)
      .sort_by { |memory| [ memory.pending? ? 0 : 1, memory.created_at, memory.id ] }
    @selected_extracted_memory = @extracted_memories.find(&:pending?)

    respond_to do |format|
      format.turbo_stream { render :refresh, status: }
      format.html { redirect_to relationship_profile_path(@relationship_profile, timeline_type: @timeline_type), notice: alert ? nil : message, alert: alert ? message : nil }
    end
  end

  def render_form(action, status:)
    @memory_extraction_enabled = memory_extraction_enabled?
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
