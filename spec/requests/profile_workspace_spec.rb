require "rails_helper"

RSpec.describe "Profile workspace", type: :request do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, preferred_name: "Maya") }

  before { sign_in user }

  it "leads with person essentials and keeps deeper workspaces collapsed" do
    get relationship_profile_path(profile)

    body = response.parsed_body
    expect(body.at_css("h1").text).to include("Maya")
    expect(body.css("[data-profile-section]").size).to eq(6)
    expect(body.css("[data-profile-section][open]")).to be_empty
    expect(body.at_css(".profile-overview").text).to include("No interaction recorded yet")
    expect(body.at_css(".profile-primary-actions a")["href"]).to include("interactions/new")
    expect(body.css("main").size).to eq(1)
  end

  it "supports server-rendered section links in Spanish without JavaScript" do
    get relationship_profile_path(profile, locale: :es, section: "moments")

    expect(response.parsed_body.at_css("details[data-profile-section][open]")["id"]).to eq("profile-moments")
    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    expect(response.parsed_body.at_css("#contact_rhythm_section")).to be_present
  end

  it "ignores unknown section identifiers" do
    get relationship_profile_path(profile, section: "all")
    expect(response.parsed_body.css("[data-profile-section][open]")).to be_empty
  end

  it "previews actual open work without revealing note bodies in the summary" do
    create(:reminder, user:, relationship_profile: profile, title: "Call Maya tomorrow")
    create(:relationship_note, relationship_profile: profile, private: true, body: "Personal context stays in About")

    get relationship_profile_path(profile)

    summary = response.parsed_body.at_css("#profile-plans > summary")
    expect(summary.text).to include("Call Maya tomorrow")
    expect(summary.text).not_to include("Personal context stays in About")
  end

  it "keeps promise preview text current through inline changes" do
    promise = create(:commitment, relationship_profile: profile, title: "Make dinner")
    get relationship_profile_path(profile)
    expect(response.parsed_body.at_css("#profile-plans > summary").text).to include("Make dinner")

    patch relationship_profile_commitment_path(profile, promise), params: { commitment: { title: "Plan a picnic" } }, as: :turbo_stream
    expect(Nokogiri::HTML(response.body).at_css("turbo-stream[target='profile_plan_preview'] template").text).to include("Plan a picnic")
    patch complete_relationship_profile_commitment_path(profile, promise), as: :turbo_stream
    expect(Nokogiri::HTML(response.body).at_css("turbo-stream[target='profile_plan_preview'] template").text.strip).to eq("")
    patch reopen_relationship_profile_commitment_path(profile, promise), as: :turbo_stream
    expect(Nokogiri::HTML(response.body).at_css("turbo-stream[target='profile_plan_preview'] template").text).to include("Plan a picnic")
    patch cancel_relationship_profile_commitment_path(profile, promise), as: :turbo_stream
    expect(Nokogiri::HTML(response.body).at_css("turbo-stream[target='profile_plan_preview'] template").text.strip).to eq("")
    delete relationship_profile_commitment_path(profile, promise), as: :turbo_stream
    expect(Nokogiri::HTML(response.body).at_css("turbo-stream[target='profile_plan_preview'] template").text.strip).to eq("")
  end

  it "uses the owner-local day for both the upcoming link and its planning target" do
    [ [ "America/Costa_Rica", Time.utc(2026, 9, 7, 2), Date.new(2026, 9, 6) ],
      [ "Pacific/Auckland", Time.utc(2026, 9, 6, 22), Date.new(2026, 9, 7) ] ].each do |zone, instant, date|
      Timecop.freeze(instant) do
        user.notification_preference&.destroy!
        create(:notification_preference, user:, time_zone: zone)
        appointment = create(:important_date, relationship_profile: profile, starts_on: date, recurrence: "none", date_type: "appointment")
        %i[en es].each do |locale|
          get relationship_profile_path(profile, locale:)
          body = response.parsed_body
          link = body.at_css("#upcoming_important_dates a[href='#planning_important_date_#{appointment.id}']")
          expect(link).to be_present
          target = body.at_css(link["href"])
          expect(target).to be_present
          expect(target.text).to include(I18n.t("important_dates.section.days_until", count: 0, locale:))
        end
      end
    end
  end

  it "removes linked reminders from the profile when their promise is deleted" do
    promise = create(:commitment, relationship_profile: profile)
    reminder = create(:reminder, user:, relationship_profile: profile, commitment: promise, title: "A promise follow-up")
    delete relationship_profile_commitment_path(profile, promise), as: :turbo_stream

    reminders = Nokogiri::HTML(response.body).at_css("turbo-stream[target='profile_reminders'] template")
    expect(reminders).to be_present
    expect(reminders.text).not_to include(reminder.title)
  end
end
