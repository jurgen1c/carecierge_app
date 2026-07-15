require "rails_helper"

RSpec.describe "Notification preferences", type: :request do
  it "requires authentication" do
    get edit_notification_preference_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "renders an owner-scoped, localized settings ledger" do
    user = create(:user)
    create(:relationship_profile, user:, preferred_name: "Elena")
    create(:relationship_profile, preferred_name: "Private person")
    sign_in user

    I18n.with_locale(:es) { get edit_notification_preference_path }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Configuración de notificaciones")
    expect(response.body).to include("Elena")
    expect(response.body).not_to include("Private person")
  end

  it "saves channel, timing, reminder, digest, and relationship choices" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    patch notification_preference_path, params: {
      notification_preference: {
        in_app_enabled: "1",
        email_enabled: "0",
        push_enabled: "1",
        sms_enabled: "1",
        quiet_hours_enabled: "1",
        quiet_hours_start: "21:30",
        quiet_hours_end: "07:15",
        time_zone: "America/Costa_Rica",
        high_priority_alerts_enabled: "0",
        reminder_frequency: "weekly",
        reminder_lead_minutes: "10080",
        digest_mode: "weekly",
        digest_time: "09:30",
        digest_weekday: "5"
      },
      relationship_notifications: { profile.id => "muted" }
    }

    expect(response).to redirect_to(edit_notification_preference_path)
    expect(user.reload.notification_preference).to have_attributes(
      in_app_enabled: true,
      email_enabled: false,
      push_enabled: true,
      sms_enabled: true,
      quiet_hours_enabled: true,
      time_zone: "America/Costa_Rica",
      high_priority_alerts_enabled: false,
      reminder_frequency: "weekly",
      reminder_lead_minutes: 10_080,
      digest_mode: "weekly",
      digest_weekday: 5
    )
    expect(user.notification_preference.relationship_notification_preferences.sole.relationship_profile_id).to eq(profile.id)
  end

  it "does not accept another user's relationship override" do
    user = create(:user)
    foreign_profile = create(:relationship_profile)
    sign_in user

    expect do
      patch notification_preference_path, params: {
        notification_preference: { email_enabled: "0" },
        relationship_notifications: { foreign_profile.id => "muted" }
      }
    end.not_to change(NotificationPreference, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "re-renders validation errors when quiet-hour times are blank" do
    user = create(:user)
    sign_in user

    patch notification_preference_path, params: {
      notification_preference: {
        quiet_hours_start: "",
        quiet_hours_end: ""
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("We could not save these notification settings")
  end
end
