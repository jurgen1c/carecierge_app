class NotificationPreferencesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }

  def edit
    prepare_settings
  end

  def update
    @notification_preference = current_user.notification_preference || current_user.build_notification_preference

    if NotificationPreferences::Save.call(
      @notification_preference,
      attributes: notification_preference_params,
      relationship_modes: relationship_notification_params
    )
      redirect_to edit_notification_preference_path, notice: t(".notice")
    else
      prepare_settings
      render :edit, status: :unprocessable_content
    end
  end

  private

  def notification_preference_params
    params.require(:notification_preference).permit(
      :in_app_enabled,
      :email_enabled,
      :push_enabled,
      :sms_enabled,
      :quiet_hours_enabled,
      :quiet_hours_start,
      :quiet_hours_end,
      :time_zone,
      :high_priority_alerts_enabled,
      :reminder_frequency,
      :reminder_lead_minutes,
      :digest_mode,
      :digest_channel,
      :digest_time,
      :digest_weekday
    )
  end

  def relationship_notification_params
    relationship_params = params[:relationship_notifications]
    return {} unless relationship_params.respond_to?(:permit)

    relationship_params.permit(*relationship_params.keys).to_h
  end

  def prepare_settings
    @notification_preference ||= current_user.notification_preference || current_user.build_notification_preference
    @relationship_profiles = current_user.relationship_profiles.active.ordered
    saved_modes = if @notification_preference.persisted?
      @notification_preference.relationship_notification_preferences.to_h { |override| [ override.relationship_profile_id, override.mode ] }
    else
      {}
    end
    @relationship_modes = saved_modes.merge(relationship_notification_params)
  end
end
