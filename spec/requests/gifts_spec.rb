require "rails_helper"

RSpec.describe "Gifts", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders gift ideas, prior gifts, and duplicate recommendation context" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      create(:gift, relationship_profile: profile, name: "Ceramic mug", status: "idea", occasion: "Birthday")
      create(:gift, relationship_profile: profile, name: "Concert tickets", status: "given", occasion: "Holiday", price_cents: 12500, vendor: "City Hall", reaction: "Loved the aisle seats.", outcome: "successful", given_on: Date.new(2026, 7, 1))
      sign_in user

      get relationship_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Gift history")
      expect(response.body).to include("Ceramic mug")
      expect(response.body).to include("Birthday")
      expect(response.body).to include("Concert tickets")
      expect(response.body).to include("$125.00")
      expect(response.body).to include("City Hall")
      expect(response.body).to include("Loved the aisle seats.")
      expect(response.body).to include("Successful")
      expect(response.body).to include("Use prior gifts to avoid repeating the same idea")
      expect(response.body).to include("gift_result[reaction]")
      expect(response.body).to include("gift_result[outcome]")
      selected_outcome = Nokogiri::HTML(response.body).at_css(%(select[name="gift_result[outcome]"] option[selected]))
      expect(selected_outcome["value"]).to eq("unknown")
      expect(response.body).to include(%(href="#{new_relationship_profile_gift_path(profile)}"))
    end

    it "renders localized gift copy in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:gift, relationship_profile: profile, name: "Taza de ceramica", status: "idea", occasion: "Cumpleaños")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Historial de regalos")
      expect(response.body).to include("Idea")
      expect(response.body).to include("Agregar regalo")
      expect(response.body).not_to include("Gift history")
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/gifts" do
    it "creates a gift idea through Turbo without leaving the profile page" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:gift, relationship_profile: profile, name: "New headphones", status: "given")
      sign_in user

      expect do
        post relationship_profile_gifts_path(profile),
          params: {
            gift: {
              name: "New headphones",
              status: "idea",
              occasion: "Birthday",
              price: "89.99",
              vendor: "Local audio shop",
              notes: "She mentioned wanting something comfortable."
            }
          },
          as: :turbo_stream
      end.to change(Gift, :count).by(1)

      gift = profile.gifts.reload.where(name: "New headphones", status: "idea").sole
      expect(gift).to have_attributes(
        relationship_profile_id: profile.id,
        name: "New headphones",
        status: "idea",
        occasion: "Birthday",
        price_cents: 8999,
        vendor: "Local audio shop"
      )
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="gifts_section"))
      expect(response.body).to include(%(<div id="flash" aria-live="polite">))
      expect(response.body).to include("New headphones")
      expect(response.body).to include("Potential repeat")
    end

    it "does not create a gift for another user's profile" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_gifts_path(profile),
          params: { gift: { name: "New headphones", status: "idea" } },
          as: :turbo_stream
      end.not_to change(Gift, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "redirects back to the profile for non-Turbo HTML fallback requests" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_gifts_path(profile),
        params: { gift: { name: "New headphones", status: "idea", occasion: "Birthday" } }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(response).to have_http_status(:found)
    end

    it "renders localized Spanish validation errors for unsupported options" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      I18n.with_locale(:es) do
        expect do
          post relationship_profile_gifts_path(profile),
            params: { gift: { name: "", status: "unknown", outcome: "unknown" } },
            as: :turbo_stream
        end.not_to change(Gift, :count)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Nombre no puede estar en blanco")
      expect(response.body).not_to include("Resultado no está incluido en la lista")
      expect(response.body).not_to include("Translation missing")
    end

    it "ignores forged terminal statuses and outcomes on generic create params" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_gifts_path(profile),
        params: { gift: { name: "Hidden success", status: "given", outcome: "successful" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(profile.gifts.reload.sole).to have_attributes(status: "idea", outcome: nil)
    end

    it "renders validation errors for prices beyond the cents column range" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_gifts_path(profile),
          params: { gift: { name: "Diamond telescope", price: "999999999999999999.99" } },
          as: :turbo_stream
      end.not_to change(Gift, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Price must be less than or equal to 21474836.47")
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/gifts/new" do
    it "returns the matching Turbo frame for lazy inline creation" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      get new_relationship_profile_gift_path(profile), headers: { "Turbo-Frame" => "new_gift" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="new_gift">))
      expect(response.body).to include("Add gift")
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/gifts/:id/edit" do
    it "returns the matching Turbo frame for inline editing" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile)
      sign_in user

      get edit_relationship_profile_gift_path(profile, gift), headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(gift) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="#{ActionView::RecordIdentifier.dom_id(gift)}">))
      expect(response.body).to include("Edit gift")
      status_options = Nokogiri::HTML(response.body).css("select#gift_status option").map { |option| option["value"] }
      expect(status_options).to eq(%w[idea planned])
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/gifts/:id" do
    it "updates a gift through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "Original")
      sign_in user

      patch relationship_profile_gift_path(profile, gift),
        params: { gift: { name: "Updated gift", vendor: "Local shop" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated gift")
      expect(gift.reload).to have_attributes(name: "Updated gift", vendor: "Local shop")
    end

    it "preserves given outcome during generic edits" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "Original", status: "given", outcome: "successful")
      sign_in user

      patch relationship_profile_gift_path(profile, gift),
        params: { gift: { name: "Updated given gift", status: "idea", outcome: "unsuccessful" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(gift.reload).to have_attributes(name: "Updated given gift", status: "given", outcome: "successful")
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/gifts/:id/mark_given" do
    it "marks a gift given and records reaction metadata" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "New headphones")
      sign_in user

      patch mark_given_relationship_profile_gift_path(profile, gift),
        params: { gift_result: { given_on: "2026-07-07", reaction: "She put them on right away.", outcome: "successful" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("New headphones")
      expect(response.body).to include("Given")
      expect(response.body).to include("She put them on right away.")
      expect(gift.reload).to be_given
    end

    it "uses the server date when no given date is submitted" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "Fresh flowers")
      sign_in user

      travel_to Time.zone.local(2026, 7, 8, 9, 0, 0) do
        patch mark_given_relationship_profile_gift_path(profile, gift), params: { gift_result: { outcome: "unknown" } }, as: :turbo_stream
      end

      expect(gift.reload.given_on).to eq(Date.new(2026, 7, 8))
    end

    it "marks a gift given from the card button without result params" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "Fresh flowers")
      sign_in user

      travel_to Time.zone.local(2026, 7, 8, 9, 0, 0) do
        patch mark_given_relationship_profile_gift_path(profile, gift), as: :turbo_stream
      end

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(gift.reload).to have_attributes(status: "given", given_on: Date.new(2026, 7, 8), outcome: "unknown")
    end

    it "rejects invalid given dates without changing the gift status" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "Fresh flowers")
      sign_in user

      patch mark_given_relationship_profile_gift_path(profile, gift),
        params: { gift_result: { given_on: "not-a-date", outcome: "unknown" } },
        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(gift.reload).to have_attributes(status: "idea", given_on: nil, outcome: nil)
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/gifts/:id" do
    it "deletes a gift through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile, name: "Camping kit")
      sign_in user

      expect do
        delete relationship_profile_gift_path(profile, gift), as: :turbo_stream
      end.to change(Gift, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="gifts_section"))
      expect(response.body).not_to include("Camping kit")
    end
  end
end
