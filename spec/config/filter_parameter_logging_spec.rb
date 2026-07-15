require "rails_helper"

RSpec.describe "parameter logging filters" do
  it "filters free-form interaction notes" do
    filtered = ActiveSupport::ParameterFilter
      .new(Rails.application.config.filter_parameters)
      .filter("interaction" => { "notes" => "Private relationship context" })

    expect(filtered.dig("interaction", "notes")).to eq("[FILTERED]")
  end
end
