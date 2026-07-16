require "rails_helper"

RSpec.describe "Important dates", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders important dates, planning suggestions, and upcoming right-rail dates" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      important_date = create(:important_date, relationship_profile: profile, date_type: "birthday", starts_on: Date.new(2020, 7, 25), recurrence: "yearly", importance_level: "high")
      create(:important_date, relationship_profile: profile, date_type: "appointment", title: "Dentist", starts_on: Date.new(2026, 7, 12), recurrence: "none")
      sign_in user

      travel_to Time.zone.local(2026, 7, 4, 10, 0, 0) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Important dates")
      expect(response.body).to include("Birthday")
      expect(response.body).to include("Dentist")
      expect(response.body).to include("Plan ahead for this birthday.")
      expect(response.body).to include("Upcoming dates")
      expect(response.body).to include("Add important date")
      expect(response.body).to include(%(href="#{new_relationship_profile_important_date_path(profile)}"))
      expect(CGI.unescapeHTML(response.body)).to include(new_reminder_path(relationship_profile_id: profile.id, important_date_id: important_date.id))
      expect(response.body).to include(%(<div id="flash" aria-live="polite">))
      expect(response.body).not_to include(%(<div id="flash" class="mb-5))
    end

    it "renders localized important date copy in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:important_date, relationship_profile: profile, date_type: "anniversary", starts_on: Date.new(2026, 8, 1), recurrence: "yearly")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fechas importantes")
      expect(response.body).to include("Aniversario")
      expect(response.body).to include("Planear con tiempo")
      expect(response.body).not_to include("Important dates")
    end

    it "only links planning controls to rendered planning suggestions" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      5.times do |index|
        create(
          :important_date,
          relationship_profile: profile,
          date_type: "milestone",
          title: "Planning date #{index + 1}",
          starts_on: Date.new(2026, 7, 10 + index),
          recurrence: "none"
        )
      end

      travel_to Time.zone.local(2026, 7, 4, 10, 0, 0) do
        get relationship_profile_path(profile)
      end

      document = Nokogiri::HTML(response.body)
      planning_hrefs = document.css("a[href^='#planning_important_date_']").map { |link| link["href"].delete_prefix("#") }
      rendered_ids = document.css("[id]").map { |element| element["id"] }

      expect(response).to have_http_status(:ok)
      expect(planning_hrefs).to be_present
      expect(planning_hrefs - rendered_ids).to be_empty
    end

    it "keeps the reminder action available for a one-time date at a timezone boundary" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      important_date = create(
        :important_date,
        relationship_profile: profile,
        starts_on: Date.new(2026, 7, 15),
        recurrence: "none"
      )
      sign_in user

      travel_to Time.utc(2026, 7, 16, 4, 30) do
        get relationship_profile_path(profile)
      end

      expect(CGI.unescapeHTML(response.body)).to include(
        new_reminder_path(relationship_profile_id: profile.id, important_date_id: important_date.id)
      )
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/important_dates" do
    it "creates an important date through Turbo without leaving the profile page" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_important_dates_path(profile),
          params: {
            important_date: {
              date_type: "birthday",
              title: "Birthday",
              starts_on: "2026-07-25",
              recurrence: "yearly",
              importance_level: "high",
              reminder_schedule: "two_weeks_before",
              notes: "Ask about dinner plans."
            }
          },
          as: :turbo_stream
      end.to change(ImportantDate, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="important_dates_section"))
      expect(response.body).to include(%(turbo-stream action="replace" target="upcoming_important_dates"))
      expect(response.body).to include(%(<div id="flash" aria-live="polite">))
      expect(response.body).not_to include(%(<div id="flash" class="mb-5))
      expect(response.body).to include("Birthday")
      expect(response.body).to include("Plan ahead")
    end

    it "does not create an important date for another user's profile" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_important_dates_path(profile),
          params: { important_date: { date_type: "birthday", starts_on: "2026-07-25" } },
          as: :turbo_stream
      end.not_to change(ImportantDate, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders localized Spanish validation errors for unsupported options" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      I18n.with_locale(:es) do
        expect do
          post relationship_profile_important_dates_path(profile),
            params: {
              important_date: {
                date_type: "unknown",
                starts_on: "2026-07-25",
                recurrence: "unknown",
                importance_level: "unknown",
                reminder_schedule: "unknown"
              }
            },
            as: :turbo_stream
        end.not_to change(ImportantDate, :count)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Tipo de fecha no está incluido en la lista")
      expect(response.body).to include("Recurrencia no está incluido en la lista")
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/important_dates/new" do
    it "returns the matching Turbo frame for lazy inline creation" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      get new_relationship_profile_important_date_path(profile), headers: { "Turbo-Frame" => "new_important_date" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="new_important_date">))
      expect(response.body).to include("Add important date")
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/important_dates/:id/edit" do
    it "returns the matching Turbo frame for inline editing" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      important_date = create(:important_date, relationship_profile: profile)
      sign_in user

      get edit_relationship_profile_important_date_path(profile, important_date), headers: { "Turbo-Frame" => ActionView::RecordIdentifier.dom_id(important_date) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="#{ActionView::RecordIdentifier.dom_id(important_date)}">))
      expect(response.body).to include("Edit important date")
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/important_dates/:id" do
    it "updates an important date through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      important_date = create(:important_date, relationship_profile: profile, title: "Original")
      sign_in user

      patch relationship_profile_important_date_path(profile, important_date),
        params: { important_date: { title: "Updated milestone", importance_level: "essential" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated milestone")
      expect(important_date.reload).to have_attributes(title: "Updated milestone", importance_level: "essential")
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/important_dates/:id" do
    it "deletes an important date through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      important_date = create(:important_date, relationship_profile: profile, title: "Dentist")
      sign_in user

      expect do
        delete relationship_profile_important_date_path(profile, important_date), as: :turbo_stream
      end.to change(ImportantDate, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="important_dates_section"))
      expect(response.body).not_to include("Dentist")
    end
  end
end
