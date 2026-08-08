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
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).sole
    other_suggestion = Suggestions::ForProfile.call(relationship_profile: other_profile).sole
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
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).sole
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
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).sole
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
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).sole
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
    suggestion = Suggestions::ForProfile.call(relationship_profile: profile).sole
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
  end
end
