require "rails_helper"

RSpec.describe "Account audit history", type: :request do
  describe "GET /audit_events" do
    it "requires authentication" do
      get audit_events_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows only the signed-in account's privacy-minimized history, even for an admin" do
      admin = create(:user, :admin)
      other_user = create(:user)
      profile = create(:relationship_profile, user: admin, first_name: "Maya")
      create(:audit_event, user: admin, actor: admin, target: profile, metadata: { "changed_fields" => "profile_details" })
      create(:audit_event, user: other_user, actor: other_user, action: "reminder.created")
      sign_in admin

      get audit_events_path

      history = Nokogiri::HTML5.fragment(response.body).at_css("section[aria-labelledby='history-heading']").text
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("audit_events.index.heading"))
      expect(history).to include(I18n.t("audit_events.actions.relationship_profile_updated.title"))
      expect(history).to include("Maya")
      expect(history).not_to include(I18n.t("audit_events.actions.reminder_created.title"))
      expect(response.body).not_to include("profile_details")
    end

    it "filters by supported actions without allowing a forged filter to broaden results" do
      user = create(:user)
      create(:audit_event, user:, actor: user, action: "reminder.created")
      create(:audit_event, user:, actor: user, action: "privacy_vault.opened")
      sign_in user

      get audit_events_path, params: { event_action: "reminder.created" }

      history = Nokogiri::HTML5.fragment(response.body).at_css("section[aria-labelledby='history-heading']").text
      expect(history).to include(I18n.t("audit_events.actions.reminder_created.title"))
      expect(history).not_to include(I18n.t("audit_events.actions.privacy_vault_opened.title"))

      get audit_events_path, params: { event_action: "private.payload.viewed" }

      history = Nokogiri::HTML5.fragment(response.body).at_css("section[aria-labelledby='history-heading']").text
      expect(history).to include(I18n.t("audit_events.index.filtered_empty_title"))
      expect(history).not_to include(I18n.t("audit_events.actions.reminder_created.title"))
    end

    it "fails closed when a filter has a non-scalar shape" do
      user = create(:user)
      create(:audit_event, user:, actor: user, action: "reminder.created")
      sign_in user

      get audit_events_path, params: { event_action: [ "reminder.created" ] }

      history = Nokogiri::HTML5.fragment(response.body).at_css("section[aria-labelledby='history-heading']").text
      expect(response).to have_http_status(:ok)
      expect(history).to include(I18n.t("audit_events.index.filtered_empty_title"))
      expect(history).not_to include(I18n.t("audit_events.actions.reminder_created.title"))
    end

    it "renders Spanish history copy" do
      user = create(:user)
      create(:audit_event, user:, actor: user)
      sign_in user

      I18n.with_locale(:es) { get audit_events_path }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("audit_events.index.heading", locale: :es))
      expect(response.body).to include(I18n.t("audit_events.index.private_title", locale: :es))
    end

    it "replaces the current page parameter in pagination links" do
      user = create(:user)
      create_list(:audit_event, 21, user:, actor: user)
      sign_in user

      get audit_events_path, params: { page: 2 }

      document = Nokogiri::HTML5.fragment(response.body)
      previous_link = document.css("nav a").find { |link| link.text.include?(I18n.t("audit_events.pagination.previous")) }
      expect(previous_link["href"].scan("page=").size).to eq(1)
    end

    it "groups and renders history in the account's saved time zone" do
      user = create(:user)
      create(:notification_preference, user:, time_zone: "America/Costa_Rica", time_zone_configured: true)
      create(:audit_event, user:, actor: user, occurred_at: Time.utc(2026, 8, 6, 5, 30))
      sign_in user

      Timecop.freeze(Time.utc(2026, 8, 6, 5, 45)) do
        get audit_events_path
      end

      document = Nokogiri::HTML5.fragment(response.body)
      expect(document.at_css("#audit-day-2026-08-05")).to be_present
      expect(document.at_css("time").text).to eq("11:30 PM")
    end
  end
end
