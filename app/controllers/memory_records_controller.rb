class MemoryRecordsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_memory_record, only: %i[edit update review approve_high_impact_automation destroy]
  around_action :serialize_memory_mutation_with_privacy_vault, only: %i[update review destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def new
    @memory_record = @relationship_profile.memory_records.new
    authorize @memory_record
  end

  def edit
  end

  def create
    @memory_record = @relationship_profile.memory_records.new(memory_record_params)
    authorize @memory_record

    if @memory_record.save
      refresh_memory_records(t(".notice"))
    else
      render_form(:new, status: :unprocessable_entity)
    end
  end

  def update
    if MemoryRecords::Update.call(user: current_user, memory_record: @memory_record,
      attributes: memory_record_params, correction_note: memory_record_correction_note)
      refresh_memory_records(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordInvalid
    @memory_record.reload
    @memory_record.errors.add(:base, t(".revision_error"))
    render_form(:edit, status: :unprocessable_entity)
  end

  def review
    if @memory_record.mark_reviewed!
      refresh_memory_records(t(".notice"))
    else
      refresh_memory_records(t(".error"), alert: true, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordInvalid
    @memory_record.reload
    refresh_memory_records(t(".error"), alert: true, status: :unprocessable_entity)
  end

  def approve_high_impact_automation
    ApprovalQueue::RecordSourceDecision.call(user: current_user, subject: @memory_record, decision: "approve")

    refresh_memory_records(t(".notice"))
  rescue ActiveRecord::RecordInvalid
    refresh_memory_records(t(".error"), alert: true, status: :unprocessable_entity)
  end

  def destroy
    @memory_record.destroy!

    refresh_memory_records(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .friendly
      .find(params[:relationship_profile_id])
  end

  def set_memory_record
    @memory_record = @relationship_profile.memory_records.find(params[:id])
    authorize @memory_record
  end

  def memory_record_params
    permitted_params = params.require(:memory_record).permit(:title, :body, :source, :confidence, :status, :stale_after)
    permitted_params.delete(:status) if permitted_params[:status].present? && !editable_status_param?(permitted_params[:status])
    permitted_params
  end

  def memory_record_correction_note
    params.require(:memory_record).permit(:correction_note)[:correction_note]
  end

  def editable_status_param?(status)
    status.in?(MemoryRecord::EDITABLE_STATUSES) && (@memory_record.blank? || @memory_record.status.in?(MemoryRecord::EDITABLE_STATUSES))
  end

  def refresh_memory_records(message, alert: false, status: :ok)
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
          action == :edit ? helpers.dom_id(@memory_record) : "new_memory_record",
          partial: "memory_records/form_frame",
          locals: { relationship_profile: @relationship_profile, memory_record: @memory_record }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end

  def serialize_memory_mutation_with_privacy_vault
    @relationship_profile.with_lock do
      @memory_record.reload
      authorize @memory_record
      yield
    end
  end
end
