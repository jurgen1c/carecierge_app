require "rails_helper"

RSpec.describe "Relationship profiles", type: :request do
  describe "GET /relationship_profiles" do
    it "requires authentication" do
      get relationship_profiles_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows only active profiles owned by the signed-in user" do
      user = create(:user)
      visible = create(:relationship_profile, user:, first_name: "Maya", last_name: "Rivera")
      create(:relationship_profile, user:, first_name: "ZeldaArchived", discarded_at: Time.current)
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
      create(:relationship_profile, user:, first_name: "Rafa", preferred_name: "Coach", type: "MentorRelationshipProfile")
      archived = create(:relationship_profile, user:, first_name: "Nora", last_name: "Lane", discarded_at: Time.current)

      sign_in user

      get relationship_profiles_path, params: { q: { RelationshipProfile::SearchQuery::SEARCH_PREDICATE => "mentor" } }

      expect(response.body).to include("Coach")
      expect(response.body).not_to include("Nora")

      get relationship_profiles_path, params: { status: "archived" }

      expect(response.body).to include(archived.full_name)
      expect(response.body).not_to include("Rafa")
    end

    it "searches rich text profile notes" do
      user = create(:user)
      visible = create(:relationship_profile, user:, first_name: "Maya", last_name: "Rivera")
      hidden = create(:relationship_profile, user:, first_name: "Nora", last_name: "Lane")
      create(:relationship_note, relationship_profile: visible, body: "<p>Met through the neighborhood garden.</p>")
      create(:relationship_note, relationship_profile: hidden, body: "<p>Prefers quiet dinners.</p>")
      sign_in user

      get relationship_profiles_path, params: { q: { RelationshipProfile::SearchQuery::SEARCH_PREDICATE => "garden" } }

      expect(response.body).to include(visible.full_name)
      expect(response.body).not_to include("Nora")
    end

    it "eager loads notes and rich text bodies for profile cards" do
      user = create(:user)
      2.times do |index|
        profile = create(:relationship_profile, user:, first_name: "Maya#{index}")
        create(:relationship_note, relationship_profile: profile, body: "<p>Garden #{index}</p>")
      end
      sign_in user

      sql = capture_sql { get relationship_profiles_path }

      expect(response).to have_http_status(:ok)
      expect(sql.grep(/FROM "relationship_notes"/).size).to eq(1)
      expect(sql.grep(/FROM "action_text_rich_texts"/).size).to eq(1)
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
      expect(response.body).to include("<lexxy-editor")
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

    it "uses friendly profile slugs in user-facing routes" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya", last_name: "Rivera")
      sign_in user

      get relationship_profile_path(profile)

      expect(relationship_profile_path(profile)).to include("maya-rivera")
      expect(response).to have_http_status(:ok)
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
            type: "FriendRelationshipProfile",
            birthday: "1992-04-12",
            contact_methods_attributes: {
              "0" => { kind: "email", value: "maya@example.com" },
              "1" => { kind: "personal_phone", value: "+506 8888 0000" }
            },
            relationship_notes_attributes: {
              "0" => { private: "0", category: "General", body: "Met through the neighborhood garden." },
              "1" => { private: "1", category: "Private", body: "Prefers low-key check-ins." }
            },
            relationship_preferences_attributes: {
              "0" => { key: "Coffee", value: "decaf" },
              "1" => { key: "Topics", value: "books" }
            },
            relationship_tags_attributes: {
              "0" => { name: "gardening" },
              "1" => { name: "book club" }
            }
          }
        }
      end.to change(RelationshipProfile, :count).by(1)
        .and change(ContactMethod, :count).by(2)
        .and change(RelationshipNote, :count).by(2)
        .and change(RelationshipPreference, :count).by(2)
        .and change(RelationshipTag, :count).by(2)

      profile = user.relationship_profiles.find_by!(first_name: "Maya")
      expect(profile.user).to eq(user)
      expect(profile.relationship_type_label).to eq("Friend")
      expect(profile.public_notes.first.body.to_plain_text).to include("Met through the neighborhood garden.")
      expect(profile.private_notes.first.body.to_plain_text).to include("Prefers low-key check-ins.")
      expect(profile.structured_preferences).to include("Coffee" => "decaf", "Topics" => "books")
      expect(profile.contact_methods.pluck(:kind, :value)).to include([ "email", "maya@example.com" ], [ "personal_phone", "+506 8888 0000" ])
      expect(response).to redirect_to(relationship_profile_path(profile))
    end

    it "stores the native STI relationship type" do
      user = create(:user)
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Kai",
            type: "MentorRelationshipProfile"
          }
        }
      end.to change(RelationshipProfile, :count).by(1)

      expect(RelationshipProfile.find_by!(first_name: "Kai")).to be_a(MentorRelationshipProfile)
    end

    it "renders validation errors instead of raising for tampered relationship type and contact kind" do
      user = create(:user)
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Kai",
            type: "BogusRelationshipProfile",
            contact_methods_attributes: {
              "0" => { kind: "pager", value: "555-1111" }
            }
          }
        }
      end.not_to change(RelationshipProfile, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Relationship type is not included in the list")
      expect(response.body).to include("Contact methods kind")
      expect(response.body).to include("blank")
    end

    it "rejects blank nested association rows" do
      user = create(:user)
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Kai",
            relationship_tags_attributes: {
              "0" => { name: "" }
            }
          }
        }
      end.not_to change(RelationshipTag, :count)

      expect(response).to redirect_to(relationship_profile_path(RelationshipProfile.find_by!(first_name: "Kai")))
    end

    it "renders validation errors for duplicate nested preferences and tags" do
      user = create(:user)
      sign_in user

      expect do
        post relationship_profiles_path, params: {
          relationship_profile: {
            first_name: "Kai",
            relationship_preferences_attributes: {
              "0" => { key: "Coffee", value: "decaf" },
              "1" => { key: " coffee ", value: "regular" }
            },
            relationship_tags_attributes: {
              "0" => { name: "garden" },
              "1" => { name: " Garden " }
            }
          }
        }
      end.not_to change(RelationshipProfile, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Relationship preferences contains duplicate keys")
      expect(response.body).to include("Relationship tags contains duplicate names")
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
          relationship_notes_attributes: {
            "0" => { private: "1", category: "Private", body: "Updated sensitive context." }
          }
        }
      }

      expect(profile.reload.first_name).to eq("Amaya")
      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.private_notes.first.body.to_plain_text).to include("Updated sensitive context.")
    end

    it "renders validation errors instead of raising when tampered update params include discriminators" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya", type: "FriendRelationshipProfile")
      contact_method = create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          type: "BogusRelationshipProfile",
          contact_methods_attributes: {
            "0" => { id: contact_method.id, kind: "pager", value: "555-1111" }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Relationship type is not included in the list")
      expect(response.body).to include("Contact methods kind")
      expect(response.body).to include("blank")
      expect(profile.reload.type).to eq("FriendRelationshipProfile")
      expect(contact_method.reload.kind).to eq("email")
    end

    it "preserves relationship details omitted from a partial update" do
      user = create(:user)
      profile = create(
        :relationship_profile,
        user:,
        type: "FriendRelationshipProfile"
      )
      create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "decaf")
      create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com")
      create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "Amaya"
        }
      }

      expect(profile.reload.relationship_type_label).to eq("Friend")
      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.structured_preferences).to eq("Coffee" => "decaf")
      expect(profile.contact_methods.pluck(:kind, :value)).to include([ "email", "maya@example.com" ])
      expect(profile.relationship_tags.pluck(:name)).to contain_exactly("garden")
    end

    it "preserves omitted contact methods when one contact field changes" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:contact_method, relationship_profile: profile, kind: "email", value: "old@example.com")
      create(:contact_method, relationship_profile: profile, kind: "personal_phone", value: "+506 1111 2222")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          contact_methods_attributes: {
            "0" => { id: profile.contact_methods.email.first.id, kind: "email", value: "new@example.com" }
          }
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(profile.contact_methods.reload.pluck(:kind, :value)).to include(
        [ "email", "new@example.com" ],
        [ "personal_phone", "+506 1111 2222" ]
      )
    end

    it "preserves preferred contact state when an existing contact value is submitted" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      contact_method = create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com", preferred: true)
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          contact_methods_attributes: {
            "0" => { id: contact_method.id, kind: "email", value: "maya@example.com" }
          }
        }
      }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(contact_method.reload).to be_preferred
    end

    it "removes nested relationship details marked for destruction" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      contact_method = create(:contact_method, relationship_profile: profile, kind: "email", value: "maya@example.com")
      note = create(:relationship_note, relationship_profile: profile, body: "Remember tea.")
      preference = create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "decaf")
      tag = create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      expect do
        patch relationship_profile_path(profile), params: {
          relationship_profile: {
            contact_methods_attributes: {
              "0" => { id: contact_method.id, kind: "email", value: contact_method.value, _destroy: "1" }
            },
            relationship_notes_attributes: {
              "0" => { id: note.id, private: "0", category: "General", body: "Remember tea.", _destroy: "1" }
            },
            relationship_preferences_attributes: {
              "0" => { id: preference.id, key: preference.key, value: preference.value, _destroy: "1" }
            },
            relationship_tags_attributes: {
              "0" => { id: tag.id, name: tag.name, _destroy: "1" }
            }
          }
        }
      end.to change(ContactMethod, :count).by(-1)
        .and change(RelationshipNote, :count).by(-1)
        .and change(RelationshipPreference, :count).by(-1)
        .and change(RelationshipTag, :count).by(-1)

      expect(response).to redirect_to(relationship_profile_path(profile))
    end

    it "preserves virtual form fields when an update is invalid" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      contact_method = create(:contact_method, relationship_profile: profile, kind: "email", value: "old@example.com")
      tag = create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "",
          contact_methods_attributes: {
            "0" => { id: contact_method.id, kind: "email", value: "new@example.com" }
          },
          relationship_tags_attributes: {
            "0" => { id: tag.id, name: "books" }
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("new@example.com")
      expect(response.body).to include("books")
      expect(profile.reload.first_name).to eq("Maya")
      expect(profile.email).to eq("old@example.com")
      expect(profile.tag_names).to eq("garden")
    end

    it "preserves blank virtual form fields when an update is invalid" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Maya")
      contact_method = create(:contact_method, relationship_profile: profile, kind: "email", value: "old@example.com")
      tag = create(:relationship_tag, relationship_profile: profile, name: "garden")
      sign_in user

      patch relationship_profile_path(profile), params: {
        relationship_profile: {
          first_name: "",
          contact_methods_attributes: {
            "0" => { id: contact_method.id, kind: "email", value: "" }
          },
          relationship_tags_attributes: {
            "0" => { id: tag.id, name: "" }
          }
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
      expect(profile.reload).to be_discarded
      expect(profile).to be_archived
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

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }

    queries
  end
end
