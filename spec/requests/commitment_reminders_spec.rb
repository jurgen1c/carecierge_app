require "rails_helper"

RSpec.describe "Commitment reminders", type: :request do
  it "preselects an open commitment and its relationship in the reminder form" do
    user = create(:user)
    profile = create(:relationship_profile, user:, first_name: "Ana")
    commitment = create(:commitment, relationship_profile: profile, title: "Send the article")
    sign_in user

    get new_reminder_path(commitment_id: commitment.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(option selected="selected" value="#{commitment.id}"))
    expect(response.body).to include("Ana")
    expect(response.body).to include("Send the article")
  end

  it "creates a reusable reminder owned by the commitment" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile)
    sign_in user

    expect do
      post reminders_path, params: {
        reminder: {
          commitment_id: commitment.id,
          title: "Follow up on the promise",
          scheduled_at: "2026-07-20T09:00",
          time_zone: "America/Costa_Rica",
          reminder_type: "promise_follow_up",
          priority: "normal",
          recurrence: "none"
        }
      }
    end.to change(Reminder, :count).by(1)

    expect(Reminder.last).to have_attributes(
      user:,
      relationship_profile_id: profile.id,
      commitment:,
      reminder_type: "promise_follow_up"
    )
  end

  it "does not expose or attach another owner's commitment" do
    user = create(:user)
    commitment = create(:commitment)
    sign_in user

    expect do
      get new_reminder_path(commitment_id: commitment.id)
    end.not_to change(Reminder, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "does not expose a foreign commitment from inconsistent persisted reminder data" do
    user = create(:user)
    reminder = create(:reminder, user:)
    foreign_commitment = create(:commitment, title: "Another owner's private promise")
    reminder.update_column(:commitment_id, foreign_commitment.id)
    sign_in user

    get edit_reminder_path(reminder)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Another owner&#39;s private promise")
  end

  it "shows owner-scoped overdue commitments in the existing reminder workspace and respects the relationship filter" do
    user = create(:user)
    selected_profile = create(:relationship_profile, user:, first_name: "Ana")
    other_profile = create(:relationship_profile, user:, first_name: "Luis")
    overdue = create(:commitment, relationship_profile: selected_profile, title: "Call Ana", due_on: 2.days.ago.to_date)
    create(:commitment, relationship_profile: other_profile, title: "Send Luis the plan", due_on: 3.days.ago.to_date)
    create(:commitment, title: "Another owner's promise", due_on: 4.days.ago.to_date)
    sign_in user

    get reminders_path(relationship_profile_id: selected_profile.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Overdue commitments")
    expect(response.body).to include(overdue.title)
    expect(response.body).not_to include("Send Luis the plan")
    expect(response.body).not_to include("Another owner&#39;s promise")
  end
end
