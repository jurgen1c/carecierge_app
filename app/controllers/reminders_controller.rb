class RemindersController < ApplicationController
  before_action :set_reminder, only: %i[edit update destroy snooze complete]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    authorize Reminder
    prepare_workspace
  end

  def new
    @reminder = current_user.reminders.new(
      relationship_profile: selected_commitment&.relationship_profile || selected_relationship_profile,
      commitment: selected_commitment
    )
    authorize @reminder
    prepare_form_options
  end

  def edit
    prepare_form_options
  end

  def create
    @reminder = current_user.reminders.new(reminder_params.except(:relationship_profile_id, :important_date_id, :commitment_id, :scheduled_at, :time_zone))
    assign_relationship_context(@reminder)
    assign_schedule(@reminder)
    authorize @reminder

    if @reminder.save
      params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
      refresh_workspace(t(".notice"))
    else
      prepare_workspace
      render_workspace(status: :unprocessable_content)
    end
  end

  def update
    saved = @reminder.with_lock do
      @reminder.assign_attributes(reminder_params.except(:relationship_profile_id, :important_date_id, :commitment_id, :scheduled_at, :time_zone))
      assign_relationship_context(@reminder)
      assign_schedule(@reminder)
      @reminder.save
    end

    if saved
      params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
      refresh_workspace(t(".notice"))
    else
      prepare_form_options
      render_form(:edit, status: :unprocessable_content)
    end
  end

  def destroy
    relationship_profile_id = @reminder.active_relationship_profile_id
    @reminder.destroy!
    params[:relationship_profile_id] ||= relationship_profile_id
    refresh_workspace(t(".notice"))
  end

  def snooze
    until_time = snooze_time(params[:snooze_for])
    @reminder.snooze!(until_time:)
    params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
    refresh_workspace(t(".notice"))
  end

  def complete
    @reminder.complete!
    params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
    refresh_workspace(t(".notice"))
  end

  def calendar
    reminders = if params[:id]
      reminder = policy_scope(Reminder).find(params[:id])
      authorize reminder, :calendar?
      [ reminder ]
    else
      authorize Reminder, :index?
      policy_scope(Reminder).active.ordered
    end

    send_data ReminderCalendarSerializer.new(reminders).to_ical,
      type: "text/calendar; charset=utf-8",
      disposition: "attachment",
      filename: params[:id] ? "carecierge-reminder.ics" : "carecierge-reminders.ics"
  end

  private

  def set_reminder
    @reminder = policy_scope(Reminder).find(params[:id])
    authorize @reminder
  end

  def selected_relationship_profile
    id = params[:relationship_profile_id].presence || params.dig(:reminder, :relationship_profile_id).presence
    return if id.blank?

    scope = action_name == "new" ? current_user.relationship_profiles.active : current_user.relationship_profiles
    scope.find(id)
  end

  def selected_commitment
    id = params[:commitment_id].presence || params.dig(:reminder, :commitment_id).presence
    return if id.blank?

    active_commitments.find(id)
  end

  def assign_relationship_context(reminder)
    permitted_params = reminder_params
    profile_supplied = permitted_params.key?(:relationship_profile_id)
    date_supplied = permitted_params.key?(:important_date_id)
    commitment_supplied = permitted_params.key?(:commitment_id)

    if profile_supplied
      profile_id = permitted_params[:relationship_profile_id].presence
      reminder.relationship_profile = if profile_id.blank?
        nil
      elsif reminder.persisted? && profile_id == reminder.relationship_profile_id
        reminder.relationship_profile
      else
        current_user.relationship_profiles.active.find(profile_id)
      end
    end

    if date_supplied
      date_id = permitted_params[:important_date_id].presence
      reminder.important_date = if date_id.blank?
        nil
      elsif reminder.persisted? && date_id == reminder.important_date_id
        reminder.important_date
      else
        active_important_dates.find(date_id)
      end
    end

    if commitment_supplied
      commitment_id = permitted_params[:commitment_id].presence
      reminder.commitment = if commitment_id.blank?
        nil
      elsif reminder.persisted? && commitment_id == reminder.commitment_id
        reminder.commitment
      else
        active_commitments.find(commitment_id)
      end
    end

    reminder.relationship_profile = reminder.commitment.relationship_profile if commitment_supplied && !profile_supplied && reminder.commitment
    reminder.relationship_profile = reminder.important_date.relationship_profile if date_supplied && !profile_supplied && reminder.important_date
    reminder.relationship_profile ||= reminder.commitment&.relationship_profile
    reminder.relationship_profile ||= reminder.important_date&.relationship_profile
  end

  def assign_schedule(reminder)
    permitted_params = reminder_params
    zone_name = permitted_params[:time_zone].presence || reminder.time_zone
    reminder.time_zone = zone_name
    return unless permitted_params.key?(:scheduled_at)

    zone = ActiveSupport::TimeZone[zone_name]
    reminder.scheduled_at = parse_local_schedule(zone, permitted_params[:scheduled_at])
  end

  def parse_local_schedule(zone, value)
    return if zone.blank? || value.blank?

    zone.strptime(value.to_s, "%Y-%m-%dT%H:%M")
  rescue ArgumentError
    nil
  end

  def snooze_time(duration)
    local_now = Time.current.in_time_zone(@reminder.time_zone)

    case duration.to_s
    when "tomorrow" then (local_now + 1.day).change(hour: 9, min: 0)
    when "next_week" then local_now + 1.week
    else local_now + 1.hour
    end
  end

  def reminder_params
    params.require(:reminder).permit(
      :relationship_profile_id,
      :important_date_id,
      :commitment_id,
      :title,
      :notes,
      :reminder_type,
      :priority,
      :recurrence,
      :scheduled_at,
      :time_zone
    )
  end

  def prepare_workspace
    @relationship_profiles = current_user.relationship_profiles.active.ordered
    @selected_relationship_profile = selected_relationship_profile
    scope = policy_scope(Reminder).active.includes(:relationship_profile, :important_date).by_effective_delivery
    scope = scope.where(relationship_profile: @selected_relationship_profile) if @selected_relationship_profile
    reminders = scope.to_a
    now = Time.current
    @overdue_reminders = reminders.select { |reminder| reminder.effective_delivery_at < now }
    @today_reminders = reminders.select { |reminder| reminder.effective_delivery_at >= now && reminder.due_today?(now) }
    @upcoming_reminders = reminders.select { |reminder| reminder.upcoming?(now) }
    @overdue_commitments = policy_scope(Commitment).overdue.includes(:relationship_profile, :reminders)
    @overdue_commitments = @overdue_commitments.where(relationship_profile: @selected_relationship_profile) if @selected_relationship_profile
    @overdue_commitments = @overdue_commitments.to_a
    @notification_preference = current_user.notification_preference || current_user.build_notification_preference
    @reminder_notifications = current_user.notifications
      .includes(event: :record)
      .where(type: "ReminderInAppNotifier::Notification")
      .order(created_at: :desc)
      .limit(5)
    prepare_form_options
  end

  def prepare_form_options
    unless @relationship_profiles
      profile_ids = current_user.relationship_profiles.active.select(:id)
      profile_ids = profile_ids.or(current_user.relationship_profiles.where(id: @reminder&.relationship_profile_id).select(:id)) if @reminder&.persisted?
      @relationship_profiles = current_user.relationship_profiles.where(id: profile_ids).ordered
    end

    active_date_ids = active_important_dates.select(:id)
    dates = ImportantDate.where(id: active_date_ids)
    dates = dates.or(ImportantDate.where(id: @reminder.important_date_id)) if @reminder&.persisted?
    @important_dates = dates
      .includes(:relationship_profile)
      .order(:starts_on, :title, :id)

    open_commitment_ids = active_commitments.select(:id)
    commitments = Commitment.where(id: open_commitment_ids)
    commitments = commitments.or(Commitment.where(id: @reminder.commitment_id)) if @reminder&.persisted? && @reminder.commitment_id
    @commitments = commitments.includes(:relationship_profile).ordered
  end

  def active_important_dates
    ImportantDate.joins(:relationship_profile).merge(current_user.relationship_profiles.active)
  end

  def active_commitments
    Commitment.joins(:relationship_profile).merge(current_user.relationship_profiles.active).where(status: "open")
  end

  def refresh_workspace(message)
    flash.now[:notice] = message
    prepare_workspace

    respond_to do |format|
      format.turbo_stream { render_workspace }
      format.html { redirect_to reminders_path(relationship_profile_id: params[:relationship_profile_id]), notice: message }
    end
  end

  def render_workspace(status: :ok)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("reminders_workspace", partial: "reminders/workspace"),
          turbo_stream.replace("flash", partial: "layouts/flash", locals: { notice: flash.now[:notice], alert: flash.now[:alert] })
        ], status:
      end
      format.html { render :index, status: }
    end
  end

  def render_form(action, status:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@reminder),
          partial: "reminders/form_frame",
          locals: { reminder: @reminder }
        ), status:
      end
      format.html { render action, status: }
    end
  end

  def not_found
    head :not_found
  end
end
