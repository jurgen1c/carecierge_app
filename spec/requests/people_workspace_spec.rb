require "rails_helper"

RSpec.describe "People workspace", type: :request do
  let(:user) { create(:user) }
  before { sign_in user }

  it "paginates a larger circle and preserves search and language in page links" do
    26.times { |index| create(:relationship_profile, user:, first_name: "Friend #{index.to_s.rjust(2, '0')}") }
    create(:relationship_profile, first_name: "Private foreign name")

    get relationship_profiles_path(locale: :es)
    expect(response.parsed_body.css("[data-person]").size).to eq(24)
    expect(response.body).not_to include("Private foreign name")
    expect(response.parsed_body.at_css("a[rel='next']")["href"]).to include("locale=es", "page=2")
    get relationship_profiles_path(page: 2)
    expect(response.parsed_body.css("[data-person]").size).to eq(2)
  end

  it "shows the last recorded interaction and upcoming date without exposing private notes" do
    now = Time.zone.local(2026, 9, 7, 10)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:interaction, relationship_profile: profile, occurred_at: now - 2.days)
    create(:important_date, relationship_profile: profile, title: "Maya's birthday", starts_on: now.to_date + 5.days)
    create(:relationship_note, relationship_profile: profile, private: true, body: "Confidential detail")

    Timecop.freeze(now) { get relationship_profiles_path }
    card = response.parsed_body.at_css("[data-person]")
    expect(card.text).to include("Maya", "Last recorded", "Maya's birthday")
    expect(card.css("time").map { |time| time["datetime"] }).to include("2026-09-05", "2026-09-12")
    expect(response.body).not_to include("Confidential detail")
    expect(response.parsed_body.at_css("details[data-people-filters]")["open"]).to be_nil
  end
end
