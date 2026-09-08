require "rails_helper"

RSpec.describe "Application workspace", type: :request do
  let(:user) { create(:user) }

  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 7, 16), &example) }

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

  it "keeps the source date and suggested schedule when changing a reminder form language" do
    profile = create(:relationship_profile, user:)
    date = create(:important_date, relationship_profile: profile, starts_on: Date.current + 5.days)
    get new_reminder_path(relationship_profile_id: profile.id, important_date_id: date.id, time_zone: "America/Costa_Rica")
    schedule = response.parsed_body.at_css("#reminder_scheduled_at")["value"]
    spanish_path = response.parsed_body.at_css(".app-language a[lang='es']")["href"]

    get spanish_path

    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    expect(response.parsed_body.at_css("#reminder_important_date_id option[selected]")["value"]).to eq(date.id)
    expect(response.parsed_body.at_css("#reminder_scheduled_at")["value"]).to eq(schedule)
    expect(response.parsed_body.at_css("#reminder_time_zone option[selected]")["value"]).to eq("America/Costa_Rica")
  end

  it "keeps the selected approval when changing language" do
    profile = create(:relationship_profile, user:)
    create(:extracted_memory, relationship_profile: profile, title: "Another review")
    selected = create(:extracted_memory, relationship_profile: profile, title: "The chosen review")
    ApprovalQueue::Synchronize.call(user:)
    approval = user.approval_requests.find_by!(subject: selected)
    get approvals_path(id: approval.id, mode: "edit", token: "not-navigation-context")
    spanish_path = response.parsed_body.at_css(".app-language a[lang='es']")["href"]
    expect(spanish_path).not_to include("not-navigation-context")

    get spanish_path

    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    expect(response.parsed_body.at_css("[data-approval-selected-item]").text).to include("The chosen review")
    expect(response.parsed_body.at_css("#approval_request_corrected_title")["value"]).to eq("The chosen review")
  end

  it "keeps the selected marketplace comparison when changing language" do
    listing = create(:marketplace_listing)
    get compare_marketplace_listings_path(listing_ids: [ listing.id ])
    expect(response).to have_http_status(:ok)

    get response.parsed_body.at_css(".app-language a[lang='es']")["href"]

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("html")["lang"]).to eq("es")
    expect(response.parsed_body.text).to include(listing.name)
  end

  it "provides working language links after a Spanish validation error" do
    post relationship_profiles_path(locale: :es), params: { relationship_profile: { first_name: "" } }
    expect(response).to have_http_status(:unprocessable_content)
    links = response.parsed_body.css(".app-language a").to_h { |link| [ link["lang"], link["href"] ] }

    %w[en es].each do |locale|
      get links.fetch(locale)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("html")["lang"]).to eq(locale)
    end
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
