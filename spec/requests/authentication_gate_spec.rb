require "rails_helper"

RSpec.describe "Authentication gate", type: :request do
  it "requires authentication by default for application controllers" do
    get dashboard_path

    expect(response).to redirect_to(new_user_session_path)
  end

  it "allows explicitly public pages to opt out" do
    get root_path

    expect(response).to have_http_status(:ok)
  end

  it "keeps Devise sign-in public" do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
  end
end
