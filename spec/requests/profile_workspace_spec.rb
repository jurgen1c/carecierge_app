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
end
