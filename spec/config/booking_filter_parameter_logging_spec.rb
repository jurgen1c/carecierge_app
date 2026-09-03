require "rails_helper"

RSpec.describe "Booking parameter filtering" do
  it "filters private booking and milestone reminder inputs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    values = {
      "title" => "Private dinner",
      "provider_name" => "Private provider",
      "starts_at" => "2026-09-20T19:00",
      "time_zone" => "America/Costa_Rica",
      "location" => "Private location",
      "confirmation_details" => "Private confirmation",
      "cancellation_policy" => "Private policy",
      "notes" => "Private notes"
    }
    filtered = filter.filter("booking" => values).fetch("booking")

    expect(filtered.values).to all(eq("[FILTERED]"))
  end
end
