require "rails_helper"

RSpec.describe "Development URL configuration" do
  it "uses HTTP for localhost links and PDF asset resolution" do
    configuration = Rails.root.join("config/environments/development.rb").read

    expect(configuration).to include('default_url_options = { host: "localhost", port: 3000, protocol: "http" }')
  end
end
