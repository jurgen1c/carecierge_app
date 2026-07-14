require "rails_helper"

RSpec.describe "Parameter filtering" do
  it "filters sensitive conversation recap content without filtering unrelated payloads" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(
      "conversation_recap" => {
        "title" => "Lunch with David",
        "body" => "Private recap details",
        "transcript" => "Private transcript details"
      },
      "body" => "Unrelated body",
      "transcript" => "Unrelated transcript"
    )

    expect(filtered.dig("conversation_recap", "body")).to eq("[FILTERED]")
    expect(filtered.dig("conversation_recap", "transcript")).to eq("[FILTERED]")
    expect(filtered.dig("conversation_recap", "title")).to eq("Lunch with David")
    expect(filtered["body"]).to eq("Unrelated body")
    expect(filtered["transcript"]).to eq("Unrelated transcript")
  end
end
