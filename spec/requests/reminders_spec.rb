require "rails_helper"

RSpec.describe "Reminders", type: :request do
  describe "dashboard discovery" do
    it "links signed-in users to the reminder inbox" do
      sign_in create(:user)

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(reminders_path)
      expect(response.body).to include("Open reminders")
    end
  end

  describe "GET /reminders" do
    it "renders the relationship-focused inbox without leaking another owner's reminders" do
      user = create(:user)
      profile = create(:relationship_profile, user:, preferred_name: "Elena")
      create(:reminder, user:, relationship_profile: profile, title: "Call Elena")
      create(:reminder, title: "Private other reminder")
      sign_in user

      get reminders_path(relationship_profile_id: profile.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Elena")
      expect(response.body).to include("Call Elena")
      expect(response.body).to include("All reminders")
      expect(response.body).to include("Export calendar")
      expect(response.body).not_to include("Private other reminder")
    end

    it "renders Spanish reminder copy" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:reminder, user:, relationship_profile: profile, title: "Llamar a Elena")
      sign_in user

      I18n.with_locale(:es) { get reminders_path(relationship_profile_id: profile.id) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recordatorios")
      expect(response.body).to include("Crear recordatorio")
      expect(response.body).not_to include("Create reminder")
    end
  end

  describe "POST /reminders" do
    it "offers a visible timezone fallback when browser timezone capture is unavailable" do
      sign_in create(:user)

      get new_reminder_path

      expect(response.body).to include(%(<select class=))
      expect(response.body).to include(%(name="reminder[time_zone]"))
      expect(response.body).to include(%(value="America/Costa_Rica"))
      expect(response.body).to include("Time zone")
      expect(response.body).not_to include(%(type="hidden" name="reminder[time_zone]"))
    end

    it "creates an owner-scoped reminder with current associations" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      important_date = create(:important_date, relationship_profile: profile)
      sign_in user

      expect do
        post reminders_path,
          params: {
            reminder: {
              relationship_profile_id: profile.id,
              important_date_id: important_date.id,
              title: "Plan birthday dinner",
              reminder_type: "birthday",
              priority: "high",
              recurrence: "yearly",
              scheduled_at: "2026-07-25T09:00"
            }
          },
          as: :turbo_stream
      end.to change(user.reminders, :count).by(1)

      reminder = user.reminders.last
      expect(reminder).to have_attributes(
        relationship_profile_id: profile.id,
        important_date_id: important_date.id,
        next_delivery_at: reminder.scheduled_at
      )
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(target="reminders_workspace"))
    end

    it "interprets a browser-local scheduled time in the submitted IANA timezone" do
      user = create(:user)
      sign_in user

      post reminders_path,
        params: {
          reminder: {
            title: "Morning check-in",
            scheduled_at: "2026-07-25T09:00",
            time_zone: "America/Costa_Rica"
          }
        }

      expect(user.reminders.last).to have_attributes(
        scheduled_at: Time.utc(2026, 7, 25, 15, 0),
        time_zone: "America/Costa_Rica"
      )
    end

    it "cannot attach a reminder to another owner's relationship" do
      user = create(:user)
      other_profile = create(:relationship_profile)
      sign_in user

      expect do
        post reminders_path,
          params: { reminder: { relationship_profile_id: other_profile.id, title: "Forged", scheduled_at: "2026-07-25T09:00" } }
      end.not_to change(Reminder, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders an HTML correction path when validation fails without Turbo" do
      sign_in create(:user)

      post reminders_path, params: { reminder: { title: "", scheduled_at: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("We could not save this reminder")
    end
  end


  describe "PATCH /reminders/:id" do
    it "preserves associations omitted from a partial update" do
      profile = create(:relationship_profile)
      important_date = create(:important_date, relationship_profile: profile)
      reminder = create(:reminder, user: profile.user, relationship_profile: profile, important_date:)
      sign_in reminder.user

      patch reminder_path(reminder), params: { reminder: { title: "Updated title" } }

      expect(reminder.reload).to have_attributes(
        title: "Updated title",
        relationship_profile_id: reminder.important_date.relationship_profile_id,
        important_date_id: reminder.important_date_id
      )
    end

    it "renders the HTML edit form when validation fails without Turbo" do
      reminder = create(:reminder)
      sign_in reminder.user

      patch reminder_path(reminder), params: { reminder: { title: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("We could not save this reminder")
    end

    it "renders an invalid timezone update through the validation correction path" do
      reminder = create(:reminder)
      sign_in reminder.user

      patch reminder_path(reminder), params: { reminder: { time_zone: "Mars/Olympus_Mons" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("We could not save this reminder")
    end

    it "keeps archived relationship context available in the edit form" do
      profile = create(:relationship_profile)
      important_date = create(:important_date, relationship_profile: profile, title: "Archived birthday")
      reminder = create(:reminder, user: profile.user, relationship_profile: profile, important_date:)
      profile.discard!
      sign_in reminder.user

      get edit_reminder_path(reminder)

      expect(response.body).to include(%(option selected="selected" value="#{profile.id}"))
      expect(response.body).to include(%(option selected="selected" value="#{important_date.id}"))
      expect(response.body).to include("data-timezone-capture-value=\"false\"")

      patch reminder_path(reminder), params: {
        reminder: {
          title: "Updated archived reminder",
          relationship_profile_id: profile.id,
          important_date_id: important_date.id,
          scheduled_at: "2026-07-25T09:00",
          time_zone: "UTC"
        }
      }

      expect(response).to redirect_to(reminders_path)
      expect(reminder.reload).to have_attributes(
        title: "Updated archived reminder",
        relationship_profile_id: profile.id,
        important_date_id: important_date.id
      )
    end

    it "renders malformed local dates through the validation correction path" do
      user = create(:user)
      sign_in user

      post reminders_path, params: {
        reminder: {
          title: "Invalid date",
          scheduled_at: "2026-99-99T09:00",
          time_zone: "America/Costa_Rica"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("We could not save this reminder")
    end
  end

  describe "reminder actions" do
    it "groups a snoozed overdue reminder by its effective delivery time" do
      now = Time.zone.local(2026, 7, 14, 9, 0)
      reminder = create(:reminder, scheduled_at: now - 1.hour)
      sign_in reminder.user

      Timecop.freeze(now) do
        patch snooze_reminder_path(reminder), params: { snooze_for: "tomorrow" }, as: :turbo_stream
      end

      expect(response.body).not_to include("Overdue")
      expect(response.body).to include("Coming up")
    end

    it "orders each timeline group by effective delivery time" do
      now = Time.zone.local(2026, 7, 14, 9, 0)
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(
        :reminder,
        user:,
        relationship_profile: profile,
        title: "Snoozed until noon",
        scheduled_at: now - 1.hour,
        snoozed_until: now + 3.hours,
        next_delivery_at: now + 3.hours
      )
      create(
        :reminder,
        user:,
        relationship_profile: profile,
        title: "Due at ten",
        scheduled_at: now + 1.hour,
        next_delivery_at: now + 1.hour
      )
      sign_in user

      Timecop.freeze(now) { get reminders_path }

      expect(response.body.index("Due at ten")).to be < response.body.index("Snoozed until noon")
    end

    it "snoozes and completes an owned reminder" do
      now = Time.zone.local(2026, 7, 14, 9, 0)
      reminder = create(:reminder, scheduled_at: now - 1.hour, next_delivery_at: nil)
      sign_in reminder.user

      Timecop.freeze(now) do
        patch snooze_reminder_path(reminder), params: { snooze_for: "one_hour" }
        expect(reminder.reload).to have_attributes(snoozed_until: now + 1.hour, next_delivery_at: now + 1.hour)

        patch complete_reminder_path(reminder)
      end

      expect(reminder.reload).to have_attributes(status: "completed", next_delivery_at: nil)
    end

    it "snoozes until tomorrow morning in the reminder timezone" do
      now = Time.utc(2026, 7, 14, 23, 30)
      reminder = create(:reminder, time_zone: "America/Costa_Rica")
      sign_in reminder.user

      Timecop.freeze(now) do
        patch snooze_reminder_path(reminder), params: { snooze_for: "tomorrow" }
      end

      expect(reminder.reload.snoozed_until).to eq(Time.utc(2026, 7, 15, 15, 0))
    end

    it "returns not found for another owner's reminder" do
      sign_in create(:user)
      reminder = create(:reminder)

      patch complete_reminder_path(reminder)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "active relationship boundaries" do
    it "rejects archived relationship and important-date associations" do
      user = create(:user)
      profile = create(:relationship_profile, user:, discarded_at: Time.current)
      important_date = create(:important_date, relationship_profile: profile, title: "Archived birthday")
      sign_in user

      post reminders_path, params: {
        reminder: {
          relationship_profile_id: profile.id,
          important_date_id: important_date.id,
          title: "Archived context",
          scheduled_at: "2026-07-25T09:00"
        }
      }

      expect(response).to have_http_status(:not_found)
      expect(user.reminders.reload).to be_empty
    end

    it "does not offer dates from archived relationships" do
      user = create(:user)
      profile = create(:relationship_profile, user:, discarded_at: Time.current)
      create(:important_date, relationship_profile: profile, title: "Archived birthday")
      sign_in user

      get new_reminder_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Archived birthday")
    end
  end

  describe "calendar export" do
    it "exports one private reminder as an iCalendar event" do
      reminder = create(:reminder, title: "Call Elena")
      sign_in reminder.user

      get calendar_reminder_path(reminder, format: :ics)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/calendar")
      expect(response.headers["Content-Disposition"]).to include("carecierge-reminder.ics")
      expect(response.body).to include("SUMMARY:Call Elena")
    end

    it "exports only the current owner's active reminders" do
      user = create(:user)
      create(:reminder, user:, relationship_profile: create(:relationship_profile, user:), title: "Owned reminder")
      create(:reminder, title: "Other reminder")
      sign_in user

      get calendar_reminders_path(format: :ics)

      expect(response.body).to include("SUMMARY:Owned reminder")
      expect(response.body).not_to include("Other reminder")
    end
  end

  describe "PATCH /notification_preference" do
    it "saves current delivery choices without enabling future channels" do
      user = create(:user)
      sign_in user

      patch notification_preference_path,
        params: { notification_preference: { in_app_enabled: "1", email_enabled: "0", push_enabled: "1", sms_enabled: "1" } }

      expect(response).to redirect_to(reminders_path)
      expect(user.reload.notification_preference).to have_attributes(
        in_app_enabled: true,
        email_enabled: false,
        push_enabled: false,
        sms_enabled: false
      )
    end
  end

  describe "relationship profile integration" do
    it "renders the profile's reminder section" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:reminder, user:, relationship_profile: profile, title: "Relationship reminder")
      sign_in user

      get relationship_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Relationship reminder")
      expect(response.body).to include("View all reminders")
    end

    it "limits profile reminders after ordering by effective delivery time" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      5.times do |index|
        create(
          :reminder,
          user:,
          relationship_profile: profile,
          title: "Upcoming #{index + 1}",
          scheduled_at: (index + 1).days.from_now
        )
      end
      create(
        :reminder,
        user:,
        relationship_profile: profile,
        title: "Snoozed late",
        scheduled_at: 1.day.ago,
        snoozed_until: 10.days.from_now
      )
      sign_in user

      get relationship_profile_path(profile)

      expect(response.body).to include("Upcoming 1", "Upcoming 5")
      expect(response.body).not_to include("Snoozed late")
    end
  end
end
