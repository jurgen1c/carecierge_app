class NotificationPreferencesController < ApplicationController
  def update
    preference = current_user.notification_preference || current_user.build_notification_preference
    preference.update!(notification_preference_params)

    redirect_to reminders_path, notice: t(".notice")
  end

  private

  def notification_preference_params
    params.require(:notification_preference).permit(:in_app_enabled, :email_enabled)
  end
end
