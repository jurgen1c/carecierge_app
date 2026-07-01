require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      raise Pundit::NotAuthorizedError
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
    sign_in create(:user)
  end

  it "renders a forbidden response for unauthorized HTML requests" do
    get :index

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to eq("Forbidden")
  end

  it "renders a forbidden response for unauthorized non-HTML requests" do
    get :index, format: :json

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to be_blank
  end
end
