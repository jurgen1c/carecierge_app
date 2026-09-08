require "rails_helper"

RSpec.describe "Application workspace", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  it "keeps the same primary destinations on standalone and nested pages" do
    profile = create(:relationship_profile, user:)
    paths = [ dashboard_path, relationship_profiles_path, relationship_profile_path(profile),
      reminders_path, new_reminder_path, event_plans_path, shared_relationship_spaces_path,
      edit_notification_preference_path, calendar_connection_path, data_control_path ]

    paths.each do |path|
      get path
      expect(response).to have_http_status(:ok)
      document = response.parsed_body
      menus = document.css("nav[data-app-navigation]")
      expect(menus.size).to eq(2), path
      expect(menus.map { |menu| menu.css("a").map { |link| link["href"] } }.uniq.size).to eq(1), path
      expect(document.css("main").size).to eq(1), path
      expect(document.at_css("html")["lang"]).to eq("en"), path
      expect(document.at_css("a[href='#main-content']")).to be_present
    end
  end

  it "selects Spanish in real requests and retains it across navigation" do
    get relationship_profiles_path(locale: :es)
    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    expect(response.body).to include("Personas")
    expect(response.parsed_body.at_css("a[data-nav-key='today']")["href"]).to eq(dashboard_path(locale: :es))

    get dashboard_path
    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    expect(response.body).to include("Hoy")
    expect(I18n.locale).to eq(:en)
  end

  it "rejects unsupported and malformed locale selections safely" do
    [ "unknown", [ "es" ], { "value" => "es" } ].each do |locale|
      get dashboard_path, params: { locale: }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("html")["lang"]).to eq("en")
    end
  end

  it "keeps language previews from changing the selected session locale" do
    get dashboard_path(locale: :en)
    expect(response.parsed_body.css(".app-language a").map { |link| link["data-turbo-prefetch"] }).to all(eq("false"))

    get dashboard_path(locale: :es), headers: { "X-Sec-Purpose" => "prefetch" }
    get dashboard_path
    expect(response.parsed_body.at_css("html")["lang"]).to eq("en")
  end

  it "never exposes administrator destinations to an ordinary owner" do
    get dashboard_path
    expect(response.parsed_body.css("nav[data-app-navigation] a[href^='/admin']")).to be_empty
  end

  it "preserves Spanish through the authentication redirect" do
    sign_out user
    get dashboard_path(locale: :es)
    expect(response).to redirect_to(new_user_session_path(locale: :es))
  end

  it "keeps the sign-in form and successful redirect in the selected language" do
    sign_out user
    get new_user_session_path(locale: :es)
    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    post user_session_path, params: { user: { email: user.email, password: "incorrect" } }
    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    post user_session_path, params: { user: { email: user.email, password: user.password } }
    expect(response).to redirect_to(onboarding_path(locale: :es))
  end
end
