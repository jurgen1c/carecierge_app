require "rails_helper"

RSpec.describe "Audit event integrations", type: :request do
  describe "relationship profile actions" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "records create, update, archive, and delete without persisting profile contents" do
      post relationship_profiles_path, params: {
        relationship_profile: {
          first_name: "Maya",
          last_name: "Rivera",
          type: "RelationshipProfiles::Friend"
        }
      }
      profile = user.relationship_profiles.find_by!(first_name: "Maya")

      patch relationship_profile_path(profile), params: {
        relationship_profile: { first_name: "May", last_name: "Rivera" }
      }
      profile.reload
      patch archive_relationship_profile_path(profile)
      expect(response).to redirect_to(relationship_profiles_path)
      delete relationship_profile_path(profile)
      expect(response).to redirect_to(relationship_profiles_path)

      expect(user.audit_events.recent_first.pluck(:action)).to match_array(
        %w[
          relationship_profile.created
          relationship_profile.updated
          relationship_profile.archived
          relationship_profile.deleted
          data_deletion.requested
        ]
      )
      expect(user.audit_events.where.not(metadata: {}).count).to eq(2)
      expect(user.audit_events.find_by!(action: "relationship_profile.updated").metadata).to eq(
        "changed_fields" => "profile_details"
      )
      expect(user.audit_events.find_by!(action: "relationship_profile.deleted")).to have_attributes(target: nil)
      expect(user.audit_events.find_by!(action: "data_deletion.requested").metadata).to eq(
        "request_kind" => "relationship_profile",
        "result" => "completed"
      )
      expect(user.audit_events.to_a.to_json).not_to include("Maya", "Rivera")
    end

    it "does not record an update for an unchanged profile submission" do
      profile = create(:relationship_profile, user:, first_name: "Maya", last_name: "Rivera")

      patch relationship_profile_path(profile), params: {
        relationship_profile: { first_name: "Maya", last_name: "Rivera" }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(user.audit_events).to be_empty
    end

    it "does not record an update when profile normalization removes the submitted difference" do
      profile = create(
        :relationship_profile,
        user:,
        type: "RelationshipProfiles::Other",
        custom_type_label: "Family friend"
      )

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: profile.first_name,
          type: profile.type,
          custom_type_label: "  Family friend  "
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.reload.custom_type_label).to eq("Family friend")
      expect(user.audit_events).to be_empty
    end
  end

  describe "reminder actions" do
    let(:user) { create(:user) }
    let(:reminder) { create(:reminder, user:) }

    before { sign_in user }

    it "records create, update, snooze, complete, and delete without reminder title or notes" do
      post reminders_path, params: {
        reminder: {
          title: "Private medication detail",
          notes: "Secret dosage",
          reminder_type: "custom",
          priority: "normal",
          recurrence: "none",
          scheduled_at: 2.days.from_now.strftime("%Y-%m-%dT%H:%M"),
          time_zone: "UTC"
        }
      }
      created_reminder = user.reminders.find_by!(title: "Private medication detail")

      patch reminder_path(reminder), params: { reminder: { title: "Updated private title" } }
      patch snooze_reminder_path(reminder), params: { snooze_for: "tomorrow" }
      patch complete_reminder_path(reminder)
      delete reminder_path(created_reminder)

      expect(user.audit_events.pluck(:action)).to match_array(
        %w[reminder.created reminder.updated reminder.snoozed reminder.completed reminder.deleted]
      )
      expect(user.audit_events.where.not(metadata: {})).to be_empty
      expect(user.audit_events.to_a.to_json).not_to include("Private medication detail", "Secret dosage", "Updated private title")
      expect(user.audit_events.find_by!(action: "reminder.deleted")).to have_attributes(target: nil)
    end

    it "does not record an update for an unchanged reminder submission" do
      reminder = create(:reminder, user:, title: "Call Maya")

      patch reminder_path(reminder), params: { reminder: { title: "Call Maya" } }

      expect(response).to redirect_to(reminders_path(relationship_profile_id: reminder.active_relationship_profile_id))
      expect(user.audit_events).to be_empty
    end
  end
end
