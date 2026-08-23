class RemindersController < ApplicationController
  before_action :set_reminder, only: %i[edit update destroy snooze complete]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    authorize Reminder
    prepare_workspace
  end

  def new
    saved_preference = current_user.notification_preference
    preference = saved_preference || NotificationPreference.new(user: current_user)
    important_date = selected_important_date
    needs_browser_time_zone = saved_preference.nil? || !saved_preference.time_zone_configured?
    captured_zone = captured_time_zone if needs_browser_time_zone
    @capture_browser_time_zone = needs_browser_time_zone && captured_zone.nil?
    @reload_after_time_zone_capture = @capture_browser_time_zone && important_date.present?
    preference.time_zone = captured_zone if captured_zone
    @reminder = current_user.reminders.new(
      relationship_profile: selected_plan_task&.event_plan&.relationship_profile || selected_event_plan&.relationship_profile || selected_commitment&.relationship_profile || important_date&.relationship_profile || selected_relationship_profile,
      important_date:,
      commitment: selected_commitment,
      event_plan: selected_event_plan,
      plan_task: selected_plan_task,
      title: selected_plan_task&.title,
      recurrence: preference.reminder_frequency,
      time_zone: preference.time_zone,
      scheduled_at: initial_schedule_for(important_date, preference)
    )
    @suggestion = selected_suggestion
    @reminder.assign_attributes(@suggestion.reminder_attributes) if @suggestion
    authorize @reminder
    prepare_form_options
  end

  def edit
    prepare_form_options
  end

  def create
    @suggestion = selected_suggestion
    @reminder = current_user.reminders.new(reminder_params.except(:relationship_profile_id, :important_date_id, :commitment_id, :event_plan_id, :plan_task_id, :scheduled_at, :time_zone))
    saved = with_reminder_persistence_locks(@reminder) do
      assign_relationship_context(@reminder)
      assign_event_planning_context(@reminder)
      assign_schedule(@reminder)
      authorize @reminder

      AuditEvents::Track.call(
        user: current_user,
        actor: current_user,
        action: "reminder.created",
        target: @reminder
      ) { Suggestions::CompleteReminderAction.call(reminder: @reminder, suggestion: @suggestion, user: current_user) }
    end

    if saved
      params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
      refresh_workspace(t(".notice"))
    else
      prepare_workspace
      render_workspace(status: :unprocessable_content)
    end
  end

  def update
    saved = with_reminder_persistence_locks(@reminder) do
      @reminder.assign_attributes(reminder_params.except(:relationship_profile_id, :important_date_id, :commitment_id, :event_plan_id, :plan_task_id, :scheduled_at, :time_zone))
      assign_relationship_context(@reminder)
      assign_event_planning_context(@reminder)
      assign_schedule(@reminder)
      AuditEvents::Track.call(
        user: current_user,
        actor: current_user,
        action: "reminder.updated",
        target: @reminder,
        record_if: @reminder.changed_for_autosave?
      ) { @reminder.save }
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
    AuditEvents::Track.call(
      user: current_user,
      actor: current_user,
      action: "reminder.deleted",
      target: nil
    ) { @reminder.destroy! }
    params[:relationship_profile_id] ||= relationship_profile_id
    refresh_workspace(t(".notice"))
  end

  def snooze
    until_time = snooze_time(params[:snooze_for])
    AuditEvents::Track.call(
      user: current_user,
      actor: current_user,
      action: "reminder.snoozed",
      target: @reminder
    ) { @reminder.snooze!(until_time:) }
    params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
    refresh_workspace(t(".notice"))
  end

  def complete
    AuditEvents::Track.call(
      user: current_user,
      actor: current_user,
      action: "reminder.completed",
      target: @reminder
    ) { @reminder.complete! }
    params[:relationship_profile_id] ||= @reminder.active_relationship_profile_id
    refresh_workspace(t(".notice"))
  end

  def calendar
    single_reminder_export = params[:id].present?
    reminders = if single_reminder_export
      reminder = policy_scope(Reminder).find(params[:id])
      authorize reminder, :calendar?
      [ reminder ]
    else
      authorize Reminder, :index?
      policy_scope(Reminder).active.ordered
    end

    calendar = ReminderCalendarSerializer.new(reminders).to_ical
    unless request.headers["X-Sec-Purpose"] == "prefetch"
      AuditEvent.record!(
        user: current_user,
        actor: current_user,
        action: "data_export.requested",
        target: single_reminder_export ? reminders.first : current_user,
        metadata: { request_kind: single_reminder_export ? "reminder_calendar" : "reminders_calendar" }
      )
    end

    send_data calendar,
      type: "text/calendar; charset=utf-8",
      disposition: "attachment",
      filename: single_reminder_export ? "carecierge-reminder.ics" : "carecierge-reminders.ics"
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

  def selected_suggestion
    fingerprint = params[:suggestion].presence
    profile = selected_relationship_profile
    return if fingerprint.blank? || profile.blank?

    Suggestions::ForProfile.call(relationship_profile: profile, gesture_variation: params[:gesture])
      .find { |suggestion| suggestion.fingerprint == fingerprint }
      .tap { |suggestion| raise ActiveRecord::RecordNotFound unless suggestion }
  end

  def selected_commitment
    id = params[:commitment_id].presence || params.dig(:reminder, :commitment_id).presence
    return if id.blank?

    active_commitments.find(id)
  end

  def selected_important_date
    id = params[:important_date_id].presence
    return if id.blank?

    active_important_dates.find(id)
  end

  def selected_event_plan
    return @selected_event_plan if defined?(@selected_event_plan)

    id = params[:event_plan_id].presence || params.dig(:reminder, :event_plan_id).presence
    @selected_event_plan = id && current_user.event_plans.for_active_relationships.where(status: "active").find(id)
  end

  def selected_plan_task
    return @selected_plan_task if defined?(@selected_plan_task)

    id = params[:plan_task_id].presence || params.dig(:reminder, :plan_task_id).presence
    return @selected_plan_task = nil unless id

    plan = selected_event_plan || raise(ActiveRecord::RecordNotFound)
    @selected_plan_task = plan.plan_tasks.current.incomplete.find(id)
  end

  def captured_time_zone
    value = params[:time_zone].presence
    value if value && ActiveSupport::TimeZone[value].present?
  end

  def default_schedule_for(important_date, preference)
    return if important_date.blank?

    zone = ActiveSupport::TimeZone[preference.time_zone]
    return if zone.blank?

    occurrence = important_date.next_occurrence_on(as_of: Time.current.in_time_zone(zone).to_date)
    return if occurrence.blank?

    reminder_date, elapsed_minutes = reminder_lead_offset(occurrence, preference.reminder_lead_minutes)
    zone.local(reminder_date.year, reminder_date.month, reminder_date.day, 9) - elapsed_minutes.minutes
  end

  def initial_schedule_for(important_date, preference)
    return if @reload_after_time_zone_capture
    return default_schedule_for(important_date, preference) if important_date
    return if @capture_browser_time_zone

    zone = ActiveSupport::TimeZone[preference.time_zone]
    return if zone.blank?

    (Time.current.in_time_zone(zone) + 1.day).change(min: 0, sec: 0)
  end

  def reminder_lead_offset(occurrence, lead_minutes)
    case lead_minutes
    when 1_440 then [ occurrence - 1.day, 0 ]
    when 10_080 then [ occurrence - 1.week, 0 ]
    when 20_160 then [ occurrence - 2.weeks, 0 ]
    when 43_200 then [ occurrence.prev_month, 0 ]
    else [ occurrence, lead_minutes ]
    end
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

  def assign_event_planning_context(reminder)
    permitted_params = reminder_params
    plan_supplied = permitted_params.key?(:event_plan_id)
    task_supplied = permitted_params.key?(:plan_task_id)

    if plan_supplied
      plan_id = permitted_params[:event_plan_id].presence
      reminder.event_plan = if plan_id.blank?
        nil
      elsif reminder.persisted? && plan_id == reminder.event_plan_id
        reminder.event_plan
      else
        current_user.event_plans.for_active_relationships.where(status: "active").find(plan_id)
      end
    end

    if task_supplied
      task_id = permitted_params[:plan_task_id].presence
      reminder.plan_task = if task_id.blank?
        nil
      elsif reminder.persisted? && task_id == reminder.plan_task_id
        reminder.plan_task
      else
        raise ActiveRecord::RecordNotFound unless reminder.event_plan

        reminder.event_plan.plan_tasks.current.incomplete.find(task_id)
      end
    end

    reminder.event_plan ||= reminder.plan_task&.event_plan
    reminder.relationship_profile ||= reminder.event_plan&.relationship_profile
  end

  def with_reminder_persistence_locks(reminder, &)
    with_record_locks(planning_lock_records(reminder)) do
      reminder.reload if reminder.persisted?
      yield
    end
  end

  def planning_lock_records(reminder)
    permitted_params = reminder_params
    plan_ids = [ reminder.event_plan_id, permitted_params[:event_plan_id] ].compact_blank
    task_ids = [ reminder.plan_task_id, permitted_params[:plan_task_id] ].compact_blank
    plans = current_user.event_plans.where(id: plan_ids).order(:id).to_a
    tasks = PlanTask.joins(:event_plan)
      .where(event_plans: { user_id: current_user.id }, id: task_ids)
      .order(:id)
      .to_a
    profile_ids = [
      reminder.relationship_profile_id,
      permitted_params[:relationship_profile_id],
      *plans.map(&:relationship_profile_id)
    ].compact_blank
    profiles = current_user.relationship_profiles.where(id: profile_ids).order(:id).to_a

    [ *profiles, *plans, *tasks, *([ reminder ] if reminder.persisted?) ]
  end

  def with_record_locks(records, index = 0, &)
    record = records[index]
    return yield if record.blank?

    record.with_lock { with_record_locks(records, index + 1, &) }
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
      :event_plan_id,
      :plan_task_id,
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
    @reminder_notifications = current_user.notifications
      .includes(event: :record)
      .where(type: [ "ReminderInAppNotifier::Notification", "DigestInAppNotifier::Notification" ])
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
    owner_commitments = policy_scope(Commitment)
    commitments = owner_commitments.where(id: open_commitment_ids)
    commitments = commitments.or(owner_commitments.where(id: @reminder.commitment_id)) if @reminder&.persisted? && @reminder.commitment_id
    @commitments = commitments.includes(:relationship_profile).ordered
  end

  def active_important_dates
    ImportantDate.joins(:relationship_profile).merge(current_user.relationship_profiles.active)
  end

  def active_commitments
    Commitment.joins(:relationship_profile).merge(current_user.relationship_profiles.active).where(status: "open")
  end

  def refresh_workspace(message)
    if @reminder&.event_plan&.then { |plan| !plan.archived? && plan.relationship_profile.kept? }
      redirect_to event_plan_path(@reminder.event_plan), notice: message
      return
    end

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
