require "rails_helper"

RSpec.describe "Desires", type: :request do
  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders desires and fulfillment history on the relationship profile" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      desire = create(:desire, relationship_profile: profile, title: "Visit Japan", category: "travel", status: "fulfilled")
      create(:desire_fulfillment, desire:, fulfilled_on: Date.new(2026, 7, 1), notes: "Booked the spring trip.")
      sign_in user

      get relationship_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Desires and ideas")
      expect(response.body).to include("Visit Japan")
      expect(response.body).to include("Travel")
      expect(response.body).to include("Fulfilled")
      expect(response.body).to include("Booked the spring trip.")
      expect(response.body).to include("Add desire")
      expect(response.body).to include(%(href="#{new_relationship_profile_desire_path(profile)}"))
    end

    it "renders localized desire copy in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:desire, relationship_profile: profile, title: "Probar ceramica", category: "gift")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deseos e ideas")
      expect(response.body).to include("Regalo")
      expect(response.body).to include("Idea de regalo, Cumpleaños y Gesto")
      expect(response.body).not_to include("Idea de regalo, Cumpleaños, and Gesto")
      expect(response.body).to include("Agregar deseo")
      expect(response.body).not_to include("Desires and ideas")
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/desires" do
    it "creates a manual desire through Turbo without leaving the profile page" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_desires_path(profile),
          params: {
            desire: {
              title: "Try pottery",
              category: "activity",
              status: "active",
              captured_on: "2026-07-07",
              notes: "Mentioned it after seeing a workshop poster."
            }
          },
          as: :turbo_stream
      end.to change(Desire, :count).by(1)

      desire = Desire.sole
      expect(desire).to have_attributes(
        relationship_profile_id: profile.id,
        title: "Try pottery",
        category: "activity",
        status: "active",
        source: "manual"
      )
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="desires_section"))
      expect(response.body).to include(%(<div id="flash" aria-live="polite">))
      expect(response.body).to include("Try pottery")
      expect(response.body).to include("Date idea")
      expect(response.body).to include("Gesture")
    end

    it "does not create a desire for another user's profile" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_desires_path(profile),
          params: { desire: { title: "New headphones", category: "gift" } },
          as: :turbo_stream
      end.not_to change(Desire, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "redirects back to the profile for non-Turbo HTML fallback requests" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_desires_path(profile),
        params: { desire: { title: "New headphones", category: "gift", status: "active" } }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(response).to have_http_status(:found)
    end

    it "renders localized Spanish validation errors for unsupported options" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      I18n.with_locale(:es) do
        expect do
          post relationship_profile_desires_path(profile),
            params: { desire: { title: "", category: "unknown", status: "unknown" } },
            as: :turbo_stream
        end.not_to change(Desire, :count)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Título no puede estar en blanco")
      expect(response.body).to include("Categoría no está incluido en la lista")
      expect(response.body).not_to include("Estado no está incluido en la lista")
      expect(response.body).not_to include("Translation missing")
    end

    it "ignores forged terminal statuses on generic create params" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_desires_path(profile),
        params: { desire: { title: "Hidden archive", category: "gift", status: "archived" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(Desire.sole).to have_attributes(status: "active", source: "manual")
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/desires/new" do
    it "returns the matching Turbo frame for lazy inline creation" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      get new_relationship_profile_desire_path(profile), headers: { "Turbo-Frame" => "new_desire" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="new_desire">))
      expect(response.body).to include("Add desire")
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/desires/:id/edit" do
    it "returns the matching Turbo frame for inline editing" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile)
      sign_in user

      get edit_relationship_profile_desire_path(profile, desire), headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(desire) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="#{ActionView::RecordIdentifier.dom_id(desire)}">))
      expect(response.body).to include("Edit desire")
      status_options = Nokogiri::HTML(response.body).css("select#desire_status option").map { |option| option["value"] }
      expect(status_options).to eq(%w[active planned])
    end

    it "does not render a status select for fulfilled desires" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile, status: "fulfilled")
      sign_in user

      get edit_relationship_profile_desire_path(profile, desire), headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(desire) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fulfilled")
      fragment = Nokogiri::HTML(response.body)
      expect(fragment.at_css("select#desire_status")).to be_nil
      expect(fragment.at_css("[name='desire[status]']")).to be_nil
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/desires/:id" do
    it "updates a desire through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile, title: "Original", category: "other")
      sign_in user

      patch relationship_profile_desire_path(profile, desire),
        params: { desire: { title: "Updated idea", category: "gift" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated idea")
      expect(desire.reload).to have_attributes(title: "Updated idea", category: "gift")
    end

    it "ignores forged terminal statuses on generic update params" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile, title: "Original", status: "active")
      sign_in user

      expect do
        patch relationship_profile_desire_path(profile, desire),
          params: { desire: { status: "fulfilled" } },
          as: :turbo_stream
      end.not_to change(DesireFulfillment, :count)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(desire.reload).to have_attributes(status: "active")
    end

    it "preserves fulfilled status during generic edits" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile, title: "Original", status: "fulfilled")
      create(:desire_fulfillment, desire:, fulfilled_on: Date.new(2026, 7, 7))
      sign_in user

      patch relationship_profile_desire_path(profile, desire),
        params: { desire: { title: "Updated fulfilled idea", status: "active" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated fulfilled idea")
      expect(desire.reload).to have_attributes(title: "Updated fulfilled idea", status: "fulfilled")
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/desires/:id/fulfill" do
    it "marks a desire fulfilled and records fulfillment history" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile, title: "New headphones")
      sign_in user

      expect do
        patch fulfill_relationship_profile_desire_path(profile, desire),
          params: { desire_fulfillment: { fulfilled_on: "2026-07-07", notes: "Sent a pair she had mentioned." } },
          as: :turbo_stream
      end.to change(DesireFulfillment, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("New headphones")
      expect(response.body).to include("Fulfilled")
      expect(response.body).to include("Sent a pair she had mentioned.")
      expect(desire.reload).to be_fulfilled
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/desires/:id" do
    it "deletes a desire through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      desire = create(:desire, relationship_profile: profile, title: "Camping")
      sign_in user

      expect do
        delete relationship_profile_desire_path(profile, desire), as: :turbo_stream
      end.to change(Desire, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="desires_section"))
      expect(response.body).not_to include("Camping")
    end
  end
end
