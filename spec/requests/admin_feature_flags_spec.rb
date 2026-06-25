require "rails_helper"

RSpec.describe "Admin feature flags", type: :request do
  describe "GET /admin/feature_flags" do
    it "requires authentication" do
      get admin_feature_flags_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "forbids non-admin users" do
      sign_in create(:user)

      get admin_feature_flags_path

      expect(response).to have_http_status(:forbidden)
    end

    it "shows flag state, assignments, rollout groups, and retired flags to admins" do
      admin = create(:user, :admin)
      flag = create(:feature_flag, key: "vendor_discovery", name: "Vendor discovery", enabled: true)
      retired = create(:feature_flag, key: "old_marketplace", name: "Old marketplace", retired_at: 1.day.ago)
      create(:feature_flag_assignment, feature_flag: flag, target_kind: "environment", target_value: "staging", enabled: true)
      create(:rollout_group, key: "early_access", name: "Early access")

      sign_in admin

      get admin_feature_flags_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Feature flags")
      expect(response.body).to include("Vendor discovery")
      expect(response.body).to include("Enabled")
      expect(response.body).to include("Assignments")
      expect(response.body).to include("Early access")
      expect(response.body).to include(retired.key)
    end

    it "renders Spanish admin registry copy when Spanish is the active locale" do
      admin = create(:user, :admin)
      create(:feature_flag, key: "vendor_discovery", name: "Vendor discovery", enabled: true)

      sign_in admin

      I18n.with_locale(:es) do
        get admin_feature_flags_path
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Solo acceso administrador")
      expect(response.body).to include("Registro de flags")
      expect(response.body).to include("Habilitada")
    end
  end
end
