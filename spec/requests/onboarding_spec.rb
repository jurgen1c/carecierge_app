require "rails_helper"

RSpec.describe "Onboarding", type: :request do
  describe "GET /onboarding" do
    it "shows the first-run setup to authenticated users" do
      sign_in create(:user)

      get onboarding_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tell us who to remember first")
      expect(response.body).to include("Initial important dates")
      expect(response.body).to include("Initial preferences")
      expect(response.body).to include("Like")
      expect(response.body).to include("Dislike")
      expect(response.body).to include("Constraint")
      expect(response.body).to include("One-time")
      expect(response.body).to include("Yearly")
      expect(response.body).to include("Reminder intent")
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
            relationship_preferences_attributes: {
              "0" => {
                preference_type: "positive",
                category: "food",
                key: "Comfort meal",
                value: "Vegetable ramen",
                confidence: "medium"
              }
            },
            important_dates_attributes: {
              "0" => {
                date_type: "birthday",
                title: "Maya's birthday",
                starts_on: "1990-05-12",
                recurrence: "yearly",
                importance_level: "high",
                reminder_schedule: "two_weeks_before"
              },
              "1" => {
                date_type: "anniversary",
                title: "Work anniversary",
                starts_on: "2021-09-01",
                recurrence: "yearly",
                importance_level: "normal",
                reminder_schedule: "month_before"
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
      expect(profile.important_dates.order(:starts_on).map(&:date_type)).to eq(%w[birthday anniversary])
      expect(profile.important_dates.order(:starts_on).first).to have_attributes(
        title: "Maya's birthday",
        recurrence: "yearly",
        importance_level: "high",
        reminder_schedule: "two_weeks_before"
      )
    end

    it "captures initial likes, dislikes, and constraints with onboarding defaults" do
      user = create(:user)
      sign_in user

      expect do
        post onboarding_path, params: {
          relationship_profile: {
            first_name: "Maya",
            type: "RelationshipProfiles::Friend",
            relationship_preferences_attributes: {
              "0" => {
                preference_type: "positive",
                category: "food",
                key: "Comfort meal",
                value: "Vegetable ramen",
                confidence: "medium",
                source_notes: "Added during onboarding."
              },
              "1" => {
                preference_type: "negative",
                category: "gifts",
                key: "Flowers",
                value: "Avoid lilies",
                confidence: "medium",
                source_notes: "Added during onboarding."
              },
              "2" => {
                preference_type: "constraint",
                category: "allergies",
                key: "Peanuts",
                value: "Allergic",
                confidence: "medium",
                source_notes: "Added during onboarding."
              }
            }
          }
        }
      end.to change(RelationshipPreference, :count).by(3)

      profile = user.relationship_profiles.sole
      preferences = profile.relationship_preferences.order(:created_at)

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(preferences.pluck(:preference_type, :category, :key, :value, :confidence, :source_notes)).to eq(
        [
          [ "positive", "food", "Comfort meal", "Vegetable ramen", "medium", "Added during onboarding." ],
          [ "negative", "gifts", "Flowers", "Avoid lilies", "medium", "Added during onboarding." ],
          [ "constraint", "allergies", "Peanuts", "Allergic", "medium", "Added during onboarding." ]
        ]
      )
    end

    it "makes the created profile available from the detail and list surfaces" do
      user = create(:user)
      sign_in user

      expect do
        post onboarding_path, params: {
          relationship_profile: {
            first_name: "Maya",
            type: "RelationshipProfiles::Friend",
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

      profile = user.relationship_profiles.sole

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.relationship_preferences.first.value).to eq("Vegetable ramen")

      follow_redirect!

      expect(response.body).to include("Maya")
      expect(response.body).to include("Vegetable ramen")

      get relationship_profiles_path

      expect(response.body).to include("Maya")
    end

    it "ignores a crafted birthday value submitted outside the onboarding form contract" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          birthday: "1990-05-12"
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.birthday).to be_nil
    end

    it "caps crafted important date rows to the three onboarding slots" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          important_dates_attributes: {
            "0" => {
              date_type: "birthday",
              title: "Birthday",
              starts_on: "1990-05-12",
              recurrence: "yearly",
              importance_level: "high",
              reminder_schedule: "two_weeks_before"
            },
            "1" => {
              date_type: "anniversary",
              title: "Work anniversary",
              starts_on: "2021-09-01",
              recurrence: "yearly",
              importance_level: "normal",
              reminder_schedule: "month_before"
            },
            "2" => {
              date_type: "appointment",
              title: "Annual checkup",
              starts_on: "2026-08-15",
              recurrence: "yearly",
              importance_level: "normal",
              reminder_schedule: "week_before"
            },
            "3" => {
              date_type: "holiday",
              title: "Crafted fourth row",
              starts_on: "2026-12-24",
              recurrence: "yearly",
              importance_level: "normal",
              reminder_schedule: "week_before"
            }
          }
        }
      }

      profile = user.relationship_profiles.last
      important_date_titles = profile.important_dates.order(:starts_on).pluck(:title)

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(important_date_titles).to contain_exactly("Birthday", "Work anniversary", "Annual checkup")
      expect(important_date_titles).not_to include("Crafted fourth row")
    end

    it "caps crafted preference rows to the three onboarding slots" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "0" => {
              preference_type: "positive",
              category: "food",
              key: "Comfort meal",
              value: "Vegetable ramen",
              confidence: "medium"
            },
            "1" => {
              preference_type: "negative",
              category: "gifts",
              key: "Flowers",
              value: "Avoid lilies",
              confidence: "medium"
            },
            "2" => {
              preference_type: "constraint",
              category: "allergies",
              key: "Peanuts",
              value: "Allergic",
              confidence: "medium"
            },
            "3" => {
              preference_type: "positive",
              category: "general",
              key: "Crafted fourth row",
              value: "Should not save",
              confidence: "medium"
            }
          }
        }
      }

      profile = user.relationship_profiles.last
      preference_keys = profile.relationship_preferences.order(:created_at).pluck(:key)

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(preference_keys).to eq([ "Comfort meal", "Flowers", "Peanuts" ])
      expect(preference_keys).not_to include("Crafted fourth row")
    end

    it "caps hash-shaped preference rows by numeric onboarding slot keys" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "3" => {
              preference_type: "positive",
              category: "general",
              key: "Crafted fourth row",
              value: "Should not save",
              confidence: "medium"
            },
            "0" => {
              preference_type: "positive",
              category: "food",
              key: "Comfort meal",
              value: "Vegetable ramen",
              confidence: "medium"
            },
            "1" => {
              preference_type: "negative",
              category: "gifts",
              key: "Flowers",
              value: "Avoid lilies",
              confidence: "medium"
            },
            "2" => {
              preference_type: "constraint",
              category: "allergies",
              key: "Peanuts",
              value: "Allergic",
              confidence: "medium"
            }
          }
        }
      }

      profile = user.relationship_profiles.last
      preference_keys = profile.relationship_preferences.order(:created_at).pluck(:key)

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(preference_keys).to eq([ "Comfort meal", "Flowers", "Peanuts" ])
      expect(preference_keys).not_to include("Crafted fourth row")
    end

    it "rejects hash-shaped preference rows outside the onboarding slot keys" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "3" => {
              preference_type: "positive",
              category: "general",
              key: "Crafted fourth row",
              value: "Should not save",
              confidence: "medium"
            },
            "99" => {
              preference_type: "negative",
              category: "general",
              key: "Crafted high row",
              value: "Should not save",
              confidence: "medium"
            }
          }
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.relationship_preferences).to be_empty
    end

    it "derives onboarding preference type and confidence from the rendered slots" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "0" => {
              preference_type: "neutral",
              category: "food",
              key: "Comfort meal",
              value: "Vegetable ramen",
              confidence: "confirmed",
              source_notes: "Tampered source"
            },
            "1" => {
              preference_type: "positive",
              category: "gifts",
              key: "Flowers",
              value: "Avoid lilies",
              confidence: "low",
              source_notes: "Tampered source"
            }
          }
        }
      }

      profile = user.relationship_profiles.last
      preferences = profile.relationship_preferences.order(:created_at)

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(preferences.pluck(:preference_type, :confidence, :source_notes)).to eq(
        [
          [ "positive", "medium", "Added during onboarding." ],
          [ "negative", "medium", "Added during onboarding." ]
        ]
      )
    end

    it "caps array-shaped important date params to the three onboarding slots" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          important_dates_attributes: [
            {
              date_type: "birthday",
              title: "Birthday",
              starts_on: "1990-05-12",
              recurrence: "yearly",
              importance_level: "high",
              reminder_schedule: "two_weeks_before"
            },
            {
              date_type: "anniversary",
              title: "Work anniversary",
              starts_on: "2021-09-01",
              recurrence: "yearly",
              importance_level: "normal",
              reminder_schedule: "month_before"
            },
            {
              date_type: "appointment",
              title: "Annual checkup",
              starts_on: "2026-08-15",
              recurrence: "yearly",
              importance_level: "normal",
              reminder_schedule: "week_before"
            },
            {
              date_type: "holiday",
              title: "Crafted fourth row",
              starts_on: "2026-12-24",
              recurrence: "yearly",
              importance_level: "normal",
              reminder_schedule: "week_before"
            }
          ]
        }
      }

      profile = user.relationship_profiles.last
      important_date_titles = profile.important_dates.order(:starts_on).pluck(:title)

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(important_date_titles).to contain_exactly("Birthday", "Work anniversary", "Annual checkup")
      expect(important_date_titles).not_to include("Crafted fourth row")
    end

    it "carries a custom relationship type label into the first profile" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Other",
          custom_type_label: "College roommate"
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile).to be_a(RelationshipProfiles::Other)
      expect(profile.custom_type_label).to eq("College roommate")
      expect(profile.relationship_type_label).to eq("College roommate")
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

    it "preserves preference slot identity when validation errors re-render onboarding" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "0" => {
              preference_type: "positive",
              category: "general",
              key: "",
              value: "",
              confidence: "medium"
            },
            "1" => {
              preference_type: "negative",
              category: "gifts",
              key: "Flowers",
              value: "Avoid lilies",
              confidence: "medium"
            }
          }
        }
      }

      document = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:unprocessable_content)
      expect(document.at_css('input[name="relationship_profile[relationship_preferences_attributes][0][preference_type]"]')["value"]).to eq("positive")
      expect(document.at_css('input[name="relationship_profile[relationship_preferences_attributes][1][preference_type]"]')["value"]).to eq("negative")
      expect(document.at_css('input[name="relationship_profile[relationship_preferences_attributes][1][key]"]')["value"]).to eq("Flowers")
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

    it "rejects tampered preference category values" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          relationship_preferences_attributes: {
            "0" => {
              preference_type: "positive",
              category: "admin_only",
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

    it "allows optional important dates to be omitted" do
      user = create(:user)
      sign_in user

      post onboarding_path, params: {
        relationship_profile: {
          first_name: "Maya",
          type: "RelationshipProfiles::Friend",
          important_dates_attributes: {
            "0" => {
              date_type: "",
              title: "",
              starts_on: "",
              recurrence: "",
              importance_level: "",
              reminder_schedule: ""
            }
          }
        }
      }

      profile = user.relationship_profiles.last

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.important_dates).to be_empty
    end

    it "rejects tampered important date enum values" do
      user = create(:user)
      sign_in user

      expect do
        post onboarding_path, params: {
          relationship_profile: {
            first_name: "Maya",
            type: "RelationshipProfiles::Friend",
            important_dates_attributes: {
              "0" => {
                date_type: "admin_only",
                starts_on: "2026-07-25",
                recurrence: "yearly",
                importance_level: "high",
                reminder_schedule: "two_weeks_before"
              }
            }
          }
        }
      end.not_to change(ImportantDate, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Important dates date type can&#39;t be blank")
      expect(user.reload.onboarding_completed_at).to be_nil
    end

    it "validates partially entered important dates" do
      user = create(:user)
      sign_in user

      expect do
        post onboarding_path, params: {
          relationship_profile: {
            first_name: "Maya",
            type: "RelationshipProfiles::Friend",
            important_dates_attributes: {
              "0" => {
                date_type: "birthday",
                title: "",
                starts_on: "",
                recurrence: "yearly",
                importance_level: "normal",
                reminder_schedule: "none"
              }
            }
          }
        }
      end.not_to change(ImportantDate, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Important dates starts on can&#39;t be blank")
      expect(user.reload.onboarding_completed_at).to be_nil
    end
  end
end
