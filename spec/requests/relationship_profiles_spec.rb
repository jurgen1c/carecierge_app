require "rails_helper"

RSpec.describe "Relationship profiles", type: :request do
  describe "GET /relationship_profiles" do
    it "requires authentication" do
      get relationship_profiles_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows only active profiles owned by the signed-in user" do
      user = create(:user)
      visible = create(:relationship_profile, user:, first_name: "Maya")
      create(:relationship_profile, user:, first_name: "ZeldaArchived", archived_at: Time.current)
      create(:relationship_profile, first_name: "HiddenPerson")

      sign_in user

      get relationship_profiles_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(visible.full_name)
      expect(response.body).not_to include("ZeldaArchived")
      expect(response.body).not_to include("HiddenPerson")
    end

    it "searches by profile details and filters archived profiles" do
      user = create(:user)
      relationship_type = create(:relationship_type, user:, name: "Mentor")
      create(:relationship_profile, user:, first_name: "Rafa", preferred_name: "Coach", relationship_type:)
      archived = create(:relationship_profile, user:, first_name: "Nora", archived_at: Time.current)

      sign_in user

      get relationship_profiles_path, params: { q: { first_name_or_last_name_or_preferred_name_or_notes_or_relationship_type_name_cont: "mentor" } }

      expect(response.body).to include("Coach")
      expect(response.body).not_to include("Nora")

      get relationship_profiles_path, params: { status: "archived" }

      expect(response.body).to include(archived.full_name)
      expect(response.body).not_to include("Rafa")
    end

    it "ignores malformed search params" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      sign_in user

      get relationship_profiles_path, params: { q: "stale-bookmark" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(profile.full_name)
    end
  end

  describe "GET /relationship_profiles/new" do
    it "renders localized Spanish copy" do
      sign_in create(:user)

      I18n.with_locale(:es) do
        get new_relationship_profile_path
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("relationship_profiles.new.heading", locale: :es))
      expect(response.body).to include(I18n.t("relationship_profiles.form.private_notes", locale: :es))
    end
  end

  describe "GET /relationship_profiles/:id" do
    it "renders controlled contact labels in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com")
      create(:contact_method, relationship_profile: profile, kind: "phone", value: "+506 1111 2222")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Correo electronico")
      expect(response.body).to include("Telefono")
    end
  end

  describe "POST /relationship_profiles" do
    it "creates a profile with core details, contact details, notes, preferences, and tags" do
      user = create(:user)
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Maya",
            last_name: "Rivera",
            preferred_name: "May",
            relationship_type_name: "Friend",
            email: "maya@example.com",
            phone: "+506 8888 0000",
            birthday: "1992-04-12",
            notes: "Met through the neighborhood garden.",
            private_notes: "Prefers low-key check-ins.",
            structured_preferences_text: "Coffee: decaf\nTopics: books",
            tag_names: "gardening, book club"
          }
        }
      end.to change(RelationshipProfile, :count).by(1)
        .and change(ContactMethod, :count).by(2)
        .and change(RelationshipTag, :count).by(2)

      profile = RelationshipProfile.find_by!(first_name: "Maya")
      expect(profile.user).to eq(user)
      expect(profile.relationship_type.name).to eq("Friend")
      expect(profile.structured_preferences).to include("Coffee" => "decaf", "Topics" => "books")
      expect(profile.contact_methods.pluck(:kind, :value)).to include([ "email", "maya@example.com" ], [ "phone", "+506 8888 0000" ])
      expect(response).to redirect_to(relationship_profile_path(profile))
    end

    it "does not create another user's relationship type with the same name" do
      user = create(:user)
      other_user = create(:user)
      create(:relationship_type, user: other_user, name: "Friend")

      sign_in user

      post relationship_profiles_path, params: {
        relationship_profile: {
          first_name: "Kai",
          relationship_type_name: "Friend"
        }
      }

      expect(user.relationship_types.pluck(:name)).to contain_exactly("Friend")
    end

    it "reuses the signed-in user's relationship type case-insensitively" do
      user = create(:user)
      relationship_type = create(:relationship_type, user:, name: "Friend")
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Kai",
            relationship_type_name: "friend"
          }
        }
      end.not_to change(RelationshipType, :count)

      expect(RelationshipProfile.find_by!(first_name: "Kai").relationship_type).to eq(relationship_type)
    end

    it "deduplicates tag names case-insensitively" do
      user = create(:user)
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Kai",
            tag_names: "family, Family"
          }
        }
      end.to change(RelationshipTag, :count).by(1)

      expect(RelationshipProfile.find_by!(first_name: "Kai").relationship_tags.pluck(:name)).to contain_exactly("Family")
    end
  end

  describe "PATCH /relationship_profiles/:id" do
    it "updates the signed-in user's profile" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "Amaya",
          private_notes: "Updated sensitive context."
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.reload.first_name).to eq("Amaya")
      expect(profile.private_notes).to eq("Updated sensitive context.")
    end

    it "preserves relationship details omitted from a partial update" do
      user = create(:user)
      relationship_type = create(:relationship_type, user:, name: "Friend")
      profile = create(
        :relationship_profile,
        user:,
        relationship_type:,
        structured_preferences: { "Coffee" => "decaf" }
      )
      create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com")
      create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "Amaya"
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.reload.relationship_type).to eq(relationship_type)
      expect(profile.structured_preferences).to eq("Coffee" => "decaf")
      expect(profile.contact_methods.pluck(:kind, :value)).to include([ "email", "maya@example.com" ])
      expect(profile.relationship_tags.pluck(:name)).to contain_exactly("garden")
    end

    it "preserves omitted contact methods when one contact field changes" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:contact_method, relationship_profile: profile, kind: "email", value: "old@example.com")
      create(:contact_method, relationship_profile: profile, kind: "phone", value: "+506 1111 2222")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          email: "new@example.com"
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.contact_methods.reload.pluck(:kind, :value)).to include(
        [ "email", "new@example.com" ],
        [ "phone", "+506 1111 2222" ]
      )
    end

    it "preserves preferred contact state when an existing contact value is submitted" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      contact_method = create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com", preferred: true)
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          email: "maya@example.com"
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(contact_method.reload).to be_preferred
    end

    it "preserves virtual form fields when an update is invalid" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      create(:contact_method, relationship_profile: profile, kind: "email", value: "old@example.com")
      create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "",
          email: "new@example.com",
          tag_names: "books, travel"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("new@example.com")
      expect(response.body).to include("books, travel")
      expect(profile.reload.first_name).to eq("Maya")
      expect(profile.email).to eq("old@example.com")
      expect(profile.tag_names).to eq("garden")
    end

    it "preserves blank virtual form fields when an update is invalid" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      create(:contact_method, relationship_profile: profile, kind: "email", value: "old@example.com")
      create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "",
          email: "",
          tag_names: ""
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include('value="old@example.com"')
      expect(response.body).not_to include('value="garden"')
      expect(profile.reload.email).to eq("old@example.com")
      expect(profile.tag_names).to eq("garden")
    end

    it "renders Spanish model attribute names in validation errors" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      sign_in user

      I18n.with_locale(:es) do
        patch relationship_profile_path(profile), params: {
          relationship_profile: {
            first_name: ""
          }
        }
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Nombre no puede estar en blanco")
      expect(response.body).not_to include("First name no puede estar en blanco")
    end

    it "does not update profiles owned by another user" do
      sign_in create(:user)
      profile = create(:relationship_profile, first_name: "Hidden")

      patch relationship_profile_path(profile), params: { relationship_profile: { first_name: "Changed" } }

      expect(response).to have_http_status(:not_found)
      expect(profile.reload.first_name).to eq("Hidden")
    end
  end

  describe "PATCH /relationship_profiles/:id/archive" do
    it "archives a profile without deleting it" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        patch archive_relationship_profile_path(profile)
      end.not_to change(RelationshipProfile, :count)

      expect(response).to redirect_to(relationship_profiles_path)
      expect(profile.reload).to be_archived
    end
  end

  describe "DELETE /relationship_profiles/:id" do
    it "deletes an owned profile and its relationship details" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:contact_method, relationship_profile: profile)
      create(:relationship_tag, relationship_profile: profile)
      sign_in user

      expect do
        delete relationship_profile_path(profile)
      end.to change(RelationshipProfile, :count).by(-1)
        .and change(ContactMethod, :count).by(-1)
        .and change(RelationshipTag, :count).by(-1)

      expect(response).to redirect_to(relationship_profiles_path)
    end
  end
end
