require "rails_helper"

RSpec.describe "Admin audit ledger", type: :request do
  describe "GET /admin/audit_events" do
    it "requires authentication" do
      get admin_audit_events_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "forbids non-admin users" do
      sign_in create(:user)

      get admin_audit_events_path

      expect(response).to have_http_status(:forbidden)
    end

    it "shows cross-account metadata to admins and filters by account" do
      admin = create(:user, :admin)
      selected_user = create(:user, email: "selected@example.com")
      other_user = create(:user, email: "hidden@example.com")
      private_relationship = create(:relationship_profile, user: selected_user, first_name: "Private relationship")
      create(:audit_event, user: selected_user, actor: selected_user, action: "reminder.created", target: private_relationship)
      create(:audit_event, user: other_user, actor: other_user, action: "relationship_profile.updated")
      sign_in admin

      get admin_audit_events_path, params: { account: "SELECTED@example.com" }

      ledger = Nokogiri::HTML5.fragment(response.body).at_css("tbody").text
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("admin.audit_events.index.heading"))
      expect(ledger).to include("selected@example.com")
      expect(ledger).to include(I18n.t("audit_events.actions.reminder_created.title"))
      expect(ledger).to include(I18n.t("audit_events.targets.relationship_profile"))
      expect(ledger).not_to include("Private relationship")
      expect(ledger).not_to include("hidden@example.com")
      expect(ledger).not_to include(I18n.t("audit_events.actions.relationship_profile_updated.title"))
    end

    it "fails closed for an unknown account instead of loading an account catalog" do
      admin = create(:user, :admin)
      create(:audit_event)
      sign_in admin

      get admin_audit_events_path, params: { account: "missing@example.com" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("admin.audit_events.index.filtered_empty_title"))
      document = Nokogiri::HTML5.fragment(response.body)
      expect(document.at_css("input[type='search'][name='account']")).to be_present
      expect(document.at_css("select[name='user_id']")).to be_nil
    end

    it "fails closed when the account filter has a non-scalar shape" do
      admin = create(:user, :admin)
      create(:audit_event)
      sign_in admin

      get admin_audit_events_path, params: { account: [ "selected@example.com" ] }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("admin.audit_events.index.filtered_empty_title"))
      expect(Nokogiri::HTML5.fragment(response.body).at_css("tbody")).to be_nil
    end

    it "renders Spanish admin ledger copy" do
      admin = create(:user, :admin)
      sign_in admin

      I18n.with_locale(:es) { get admin_audit_events_path }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("admin.audit_events.index.heading", locale: :es))
      expect(response.body).to include(I18n.t("admin.audit_events.index.admin_only", locale: :es))
    end
  end
end
