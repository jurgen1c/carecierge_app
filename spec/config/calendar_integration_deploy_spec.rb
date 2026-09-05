require "rails_helper"
require "erb"

RSpec.describe "Calendar integration deployment configuration" do
  it "forwards dedicated Google Calendar OAuth credentials without storing secret values" do
    deploy_config = YAML.safe_load(ERB.new(Rails.root.join("config/deploy.yml").read).result)
    secrets = Rails.root.join(".kamal/secrets").read

    expect(deploy_config.dig("env", "secret")).to include(
      "GOOGLE_CALENDAR_CLIENT_ID",
      "GOOGLE_CALENDAR_CLIENT_SECRET"
    )
    expect(secrets).to include(
      "GOOGLE_CALENDAR_CLIENT_ID=$GOOGLE_CALENDAR_CLIENT_ID",
      "GOOGLE_CALENDAR_CLIENT_SECRET=$GOOGLE_CALENDAR_CLIENT_SECRET"
    )
  end
end
