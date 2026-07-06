require "rails_helper"

RSpec.describe "Onboarding", type: :request do
  describe "GET /onboarding" do
    it "shows the first-run setup to authenticated users" do
      sign_in create(:user)

      get onboarding_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tell us who to remember first")
      expect(response.body).to include("Save first relationship")
    end
  end

  describe "POST /onboarding/skip" do
    it "lets users skip onboarding and return later from the dashboard" do
      user = create(:user)
      sign_in user

      post skip_onboarding_path

      expect(response).to redirect_to(dashboard_path)
      expect(user.reload.onboarding_skipped_at).to be_present
      expect(user.onboarding_completed_at).to be_nil

      follow_redirect!

      expect(response.body).to include("Continue onboarding")
    end
  end

  describe "POST /onboarding" do
    it "creates the first useful relationship profile and completes onboarding" do
      user = create(:user)
      sign_in user

      expect do
        post onboarding_path, params: {
          relationship_profile: {
            first_name: "Maya",
            type: "RelationshipProfiles::Friend",
            birthday: "1990-05-12",
            relationship_preferences_attributes: {
              "0" => {
                preference_type: "positive",
                category: "food",
                key: "Comfort meal",
                value: "Vegetable ramen",
                confidence: "medium"
              }
            }
          }
        }
      end.to change(user.relationship_profiles, :count).by(1)

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(user.reload.onboarding_completed_at).to be_present
      expect(profile.first_name).to eq("Maya")
      expect(profile.relationship_preferences.first.value).to eq("Vegetable ramen")
    end

    it "renders validation errors without completing onboarding" do
      user = create(:user)
      sign_in user

      expect do
        post onboarding_path, params: {
          relationship_profile: {
            first_name: "",
            type: "RelationshipProfiles::Friend"
          }
        }
      end.not_to change(user.relationship_profiles, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Review this field")
      expect(user.reload.onboarding_completed_at).to be_nil
    end

    it "accepts a missing relationship type and lets the profile default it" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya"
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.type).to eq(RelationshipProfile::DEFAULT_TYPE)
    end

    it "accepts a blank relationship type and lets the profile default it" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: ""
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.type).to eq(RelationshipProfile::DEFAULT_TYPE)
    end

    it "rejects a tampered relationship type" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Admin"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.onboarding_completed_at).to be_nil
    end

    it "rejects tampered preference enum values" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "0" => {
              preference_type: "admin_only",
              category: "general",
              key: "Comfort meal",
              value: "Vegetable ramen",
              confidence: "medium"
            }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.onboarding_completed_at).to be_nil
    end

    it "allows optional preference details to be omitted" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "0" => {
              key: "",
              value: ""
            }
          }
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.relationship_preferences).to be_empty
    end
  end
end
