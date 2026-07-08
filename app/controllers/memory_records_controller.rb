class MemoryRecordsController < ApplicationController
  before_action :set_relationship_profile
  before_action :set_memory_record, only: %i[edit update review approve_high_impact_automation destroy]

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
    previous_body = @memory_record.body
    note = memory_record_correction_note
    attrs = memory_record_params
    trust_relevant_change = trust_relevant_change?(attrs)
    mark_corrected = attrs.key?(:body) && attrs[:body].to_s.strip != previous_body.to_s.strip
    attrs[:source] = "user_corrected" if mark_corrected
    attrs[:status] = "corrected" if mark_corrected
    attrs[:reviewed_at] = nil if trust_relevant_change
    attrs[:high_impact_automation_approved_at] = nil if trust_relevant_change

    if @memory_record.update(attrs)
      create_revision(previous_body, note) if mark_corrected
      refresh_memory_records(t(".notice"))
    else
      render_form(:edit, status: :unprocessable_entity)
    end
  end

  def review
    @memory_record.mark_reviewed!

    refresh_memory_records(t(".notice"))
  end

  def approve_high_impact_automation
    @memory_record.approve_high_impact_automation!

    refresh_memory_records(t(".notice"))
  end

  def destroy
    @memory_record.destroy!

    refresh_memory_records(t(".notice"))
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .includes(:memory_records)
      .friendly
      .find(params[:relationship_profile_id])
  end

  def set_memory_record
    @memory_record = @relationship_profile.memory_records.find(params[:id])
    authorize @memory_record
  end

  def memory_record_params
    params.require(:memory_record).permit(:title, :body, :source, :confidence, :status, :stale_after)
  end

  def memory_record_correction_note
    params.require(:memory_record).permit(:correction_note)[:correction_note]
  end

  def trust_relevant_change?(attrs)
    %i[title body source confidence status].any? do |key|
      attrs.key?(key) && attrs[key].to_s.strip != @memory_record.public_send(key).to_s
    end
  end

  def create_revision(previous_body, note)
    @memory_record.memory_revisions.create!(
      user: current_user,
      previous_body:,
      revised_body: @memory_record.body,
      note:
    )
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
end
