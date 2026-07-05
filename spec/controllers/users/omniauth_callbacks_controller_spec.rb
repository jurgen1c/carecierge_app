require "rails_helper"

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  routes { Rails.application.routes }

  before do
    request.env["devise.mapping"] = Devise.mappings[:user]
    request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "google-123",
      info: { email: "user@example.com" }
    )
  end

  describe "GET #google_oauth2" do
    it "signs in and redirects the Google-authenticated user" do
      get :google_oauth2

      user = User.find_by!(email: "user@example.com")
      expect(controller.current_user).to eq(user)
      expect(response).to redirect_to(onboarding_path)
    end

    it "handles non-navigational requests without setting a flash" do
      get :google_oauth2, format: :json

      expect(flash).to be_empty
      expect(response).to redirect_to(onboarding_path)
    end
  end
end
