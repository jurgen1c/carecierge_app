require "rails_helper"
require Rails.root.join("lib/development_seeds/world")

RSpec.describe "Development journey manifest", type: :system do
  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 6, 12)) { example.run } }

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
    @world = DevelopmentSeeds::World.new
    @world.seed!
  end

  it "walks the available owner journeys in English and Spanish" do
    %w[en es].each do |locale|
      user = @world.users.fetch("owner_#{locale}")
      sign_in user
      paths = [
        "/relationship_profiles/alex-synthetic-owner_#{locale}",
        "/relationship_profiles/alex-synthetic-owner_#{locale}/privacy_vault",
        "/vault_mfa", "/reminders", "/notification_preference/edit", "/event_plans",
        "/shared_relationship_spaces", "/relationship_profiles/sam-synthetic-colleague-owner_#{locale}",
        "/calendar_connection", "/contacts_connection", "/messaging_connection"
      ]
      paths.each do |path|
        visit "#{path}?locale=#{locale}"
        expect(page).to have_css("main")
        expect(page).to have_current_path("#{path}?locale=#{locale}")
        expect(page).not_to have_text("Routing Error")
      end
      visit "/relationship_profiles/alex-synthetic-owner_#{locale}?locale=#{locale}"
      find("#profile-notes > summary").click
      expect(page).to have_text("Jasmine tea")
      expect(page).to have_text("Synthetic failed extraction")
      expect(page).not_to have_text("Fictional private context for vault walkthrough.")
      @world.users.fetch("owner_#{locale}").owned_shared_relationship_spaces.each do |space|
        visit "/shared_relationship_spaces/#{space.id}?locale=#{locale}"
        expect(page).to have_text("Synthetic shared picnic")
        expect(page).not_to have_text("Jasmine tea")
      end
      sign_out user
    end
  end

  it "opens both onboarding locales, vendor submission and admin moderation" do
    %w[en es].each do |locale|
      user = @world.users.fetch("new_#{locale}")
      sign_in user
      visit "/onboarding?locale=#{locale}"
      expect(page).to have_css("main")
      expect(page).to have_current_path("/onboarding?locale=#{locale}")
      sign_out user
    end
    sign_in @world.users.fetch("vendor")
    visit "/vendor_account?locale=en"
    expect(page).to have_field("Business name", with: "Synthetic Orchid Studio")
    sign_out @world.users.fetch("vendor")
    sign_in @world.users.fetch("admin")
    visit "/admin/vendor_accounts"
    expect(page).to have_text("Synthetic Orchid Studio")
    visit "/admin"
    expect(page).to have_css("main")
  end
end
