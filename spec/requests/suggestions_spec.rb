require "rails_helper"

RSpec.describe "Suggestions", type: :request do
  it "renders a selectable source-backed suggestion inspector on an owned profile" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(
      :relationship_preference,
      relationship_profile: profile,
      category: "communication",
      key: "Message style",
      value: "Short and sincere",
      confidence: "confirmed"
    )
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Suggested next steps")
    expect(response.body).to include("Send Maya a quick message")
    expect(response.body).to include("Why this appears")
    expect(response.body).to include("Short and sincere")
    expect(response.body).to include("Confirmed")
    expect(response.body).to include("This creates a private reminder for you. It does not contact anyone automatically.")
  end

  it "records feedback and dismissal without accepting another owner's suggestion" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    other_profile = create(:relationship_profile)
    create(:relationship_preference, relationship_profile: other_profile, confidence: "confirmed")
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).find { |item| item.suggestion_type == "message" }
    other_suggestion = Suggestions::ForProfile.call(relationship_profile: other_profile).find { |item| item.suggestion_type == "message" }
    sign_in user

    patch feedback_relationship_profile_suggestion_path(profile, suggestion.fingerprint),
      params: { feedback: "helpful" },
      as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('turbo-stream action="replace" target="suggestions_section"')
    expect(user.suggestion_feedbacks.find_by!(fingerprint: suggestion.fingerprint).feedback).to eq("helpful")

    patch dismiss_relationship_profile_suggestion_path(profile, suggestion.fingerprint), as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(suggestion.title)

    patch feedback_relationship_profile_suggestion_path(profile, other_suggestion.fingerprint),
      params: { feedback: "helpful" }

    expect(response).to have_http_status(:not_found)
  end

  it "rejects unsupported feedback without persisting interaction state" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).find { |item| item.suggestion_type == "message" }
    sign_in user

    patch feedback_relationship_profile_suggestion_path(profile, suggestion.fingerprint),
      params: { feedback: "surprising" },
      as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.suggestion_feedbacks.where(fingerprint: suggestion.fingerprint)).not_to exist
  end

  it "generates suggestions once while recording feedback" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).find { |item| item.suggestion_type == "message" }
    sign_in user
    expect(Suggestions::ForProfile).to receive(:call).once.and_call_original

    patch feedback_relationship_profile_suggestion_path(profile, suggestion.fingerprint),
      params: { feedback: "helpful" },
      as: :turbo_stream

    expect(response).to have_http_status(:ok)
  end

  it "prefills a reminder and marks the suggestion acted only after the reminder saves" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    create(:notification_preference, user:, time_zone: "America/Costa_Rica", time_zone_configured: true)
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).find { |item| item.suggestion_type == "message" }
    sign_in user

    post act_relationship_profile_suggestion_path(profile, suggestion.fingerprint)

    expect(response).to redirect_to(new_reminder_path(relationship_profile_id: profile.id, suggestion: suggestion.fingerprint))
    expect(user.suggestion_feedbacks.find_by(fingerprint: suggestion.fingerprint)).to be_nil

    follow_redirect!

    expect(response.body).to include(%(value="#{suggestion.title}"))
    expect(response.body).to include(%(name="suggestion"))
    expect(response.body).to include(%(value="#{suggestion.fingerprint}"))

    expect do
      post reminders_path,
        params: {
          suggestion: suggestion.fingerprint,
          reminder: {
            relationship_profile_id: profile.id,
            title: suggestion.title,
            reminder_type: "check_in",
            priority: "normal",
            recurrence: "none",
            scheduled_at: "2026-08-09T09:00",
            time_zone: "America/Costa_Rica"
          }
        }
    end.to change(Reminder, :count).by(1)

    expect(user.suggestion_feedbacks.find_by!(fingerprint: suggestion.fingerprint)).to be_hidden
  end

  it "does not mark a suggestion acted when reminder creation fails" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    create(:notification_preference, user:, time_zone: "America/Costa_Rica", time_zone_configured: true)
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).find { |item| item.suggestion_type == "message" }
    sign_in user

    post reminders_path,
      params: {
        suggestion: suggestion.fingerprint,
        reminder: {
          relationship_profile_id: profile.id,
          title: "",
          reminder_type: "check_in",
          priority: "normal",
          recurrence: "none",
          scheduled_at: "2026-08-09T09:00",
          time_zone: "America/Costa_Rica"
        }
      }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.suggestion_feedbacks.find_by(fingerprint: suggestion.fingerprint)).to be_nil
  end

  it "renders Spanish suggestion copy" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    sign_in user

    I18n.with_locale(:es) { get relationship_profile_path(profile) }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Próximos pasos sugeridos")
    expect(response.body).to include("Por qué aparece")
    expect(response.body).to include("Crear recordatorio")
    expect(response.body).not_to include("Translation missing")

    I18n.with_locale(:es) do
      get relationship_profile_path(profile, gesture: "low", suggestion_type: "spontaneous")
    end

    expect(response.body).to include("Poco esfuerzo")
    expect(response.body).to include("Guardar")
    expect(response.body).to include("Marcar como completado")
    expect(response.body).to include("Mostrar otra")
    expect(response.body).not_to include("Translation missing")
  end

  it "rotates, saves, and completes owner-scoped gesture alternatives" do
    now = Time.zone.local(2026, 8, 19, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, preference_type: "positive", value: "Fresh pastries")
    sign_in user

    Timecop.freeze(now) do
      medium = Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of: now,
        gesture_variation: "medium"
      ).find(&:gesture?)

      get relationship_profile_path(profile, gesture: "medium", suggestion_type: "spontaneous")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Medium effort")
      expect(response.body).to include(medium.title)

      patch save_relationship_profile_suggestion_path(profile, medium.fingerprint, gesture: "medium"), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(user.suggestion_feedbacks.find_by!(fingerprint: medium.fingerprint)).to be_saved_for_later
      expect(response.body).to include("Saved")

      patch complete_relationship_profile_suggestion_path(profile, medium.fingerprint, gesture: "medium"), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(user.suggestion_feedbacks.find_by!(fingerprint: medium.fingerprint)).to be_hidden
      expect(response.body).not_to include(medium.title)
    end
  end

  it "skips hidden gesture alternatives in the profile controls" do
    now = Time.zone.local(2026, 8, 19, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    sign_in user

    Timecop.freeze(now) do
      medium = Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of: now,
        gesture_variation: "medium"
      ).find(&:gesture?)
      high = Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of: now,
        gesture_variation: "high"
      ).find(&:gesture?)
      create(:suggestion_feedback, user:, relationship_profile: profile, fingerprint: medium.fingerprint, acted_at: now)

      get relationship_profile_path(profile, gesture: "low", suggestion_type: "spontaneous")

      alternative_link = Nokogiri::HTML(response.body).at_css("a[href*='gesture=high']")
      expect(alternative_link&.text&.strip).to eq("Show another")

      create(:suggestion_feedback, user:, relationship_profile: profile, fingerprint: high.fingerprint, dismissed_at: now)

      get relationship_profile_path(profile, gesture: "low", suggestion_type: "spontaneous")

      expect(response.body).not_to include("Show another")
    end
  end

  it "preserves the selected gesture effort for HTML save and completion fallbacks" do
    now = Time.zone.local(2026, 8, 19, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, preference_type: "positive", value: "Fresh pastries")
    medium = Suggestions::ForProfile.call(
      relationship_profile: profile,
      as_of: now,
      gesture_variation: "medium"
    ).find(&:gesture?)
    sign_in user

    Timecop.freeze(now) do
      patch save_relationship_profile_suggestion_path(profile, medium.fingerprint, gesture: "medium")

      expect(response).to redirect_to(relationship_profile_path(
        profile,
        suggestion: medium.fingerprint,
        gesture: "medium"
      ))
      follow_redirect!
      expect(response.body).to include("Medium effort", "Saved", medium.title)

      patch complete_relationship_profile_suggestion_path(profile, medium.fingerprint, gesture: "medium")

      expect(response.location).to include("gesture=medium")
      follow_redirect!
      expect(response.body).not_to include(medium.title)
    end
  end

  it "does not allow another owner to save or complete a gesture" do
    profile = create(:relationship_profile)
    gesture = Suggestions::ForProfile.call(relationship_profile: profile, gesture_variation: "low").find(&:gesture?)
    sign_in create(:user)

    patch save_relationship_profile_suggestion_path(profile, gesture.fingerprint, gesture: "low")
    expect(response).to have_http_status(:not_found)

    patch complete_relationship_profile_suggestion_path(profile, gesture.fingerprint, gesture: "low")
    expect(response).to have_http_status(:not_found)
  end

  it "carries a relationship-type gesture through reminder creation before marking it complete" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:notification_preference, user:, time_zone: "America/Costa_Rica", time_zone_configured: true)
    gesture = Suggestions::ForProfile.call(relationship_profile: profile, gesture_variation: "low").find(&:gesture?)
    sign_in user

    post act_relationship_profile_suggestion_path(profile, gesture.fingerprint, gesture: "low")

    expect(response).to redirect_to(new_reminder_path(
      relationship_profile_id: profile.id,
      suggestion: gesture.fingerprint,
      gesture: "low"
    ))
    follow_redirect!
    expect(response.body).to include(%(name="gesture" id="gesture" value="low"))
    expect(response.body).to include(%(value="#{gesture.title}"))

    expect do
      post reminders_path,
        params: {
          suggestion: gesture.fingerprint,
          gesture: "low",
          reminder: {
            relationship_profile_id: profile.id,
            title: gesture.title,
            reminder_type: "check_in",
            priority: "normal",
            recurrence: "none",
            scheduled_at: "2026-08-21T09:00",
            time_zone: "America/Costa_Rica"
          }
        }
    end.to change(Reminder, :count).by(1)

    expect(user.suggestion_feedbacks.find_by!(fingerprint: gesture.fingerprint)).to be_hidden
  end
end
