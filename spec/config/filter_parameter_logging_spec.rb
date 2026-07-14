require "rails_helper"

RSpec.describe "Parameter filtering" do
  it "filters sensitive relationship content without filtering unrelated payloads" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(
      "conversation_recap" => {
        "title" => "Lunch with David",
        "body" => "Private recap details",
        "transcript" => "Private transcript details"
      },
      "mood_note" => {
        "category" => "stressed",
        "observation" => "Private mood observation",
        "supportive_action" => "Private support plan"
      },
      "body" => "Unrelated body",
      "transcript" => "Unrelated transcript",
      "observation" => "Unrelated observation",
      "supportive_action" => "Unrelated support plan"
    )

    expect(filtered.dig("conversation_recap", "body")).to eq("[FILTERED]")
    expect(filtered.dig("conversation_recap", "transcript")).to eq("[FILTERED]")
    expect(filtered.dig("conversation_recap", "title")).to eq("Lunch with David")
    expect(filtered.dig("mood_note", "observation")).to eq("[FILTERED]")
    expect(filtered.dig("mood_note", "supportive_action")).to eq("[FILTERED]")
    expect(filtered.dig("mood_note", "category")).to eq("stressed")
    expect(filtered["body"]).to eq("Unrelated body")
    expect(filtered["transcript"]).to eq("Unrelated transcript")
    expect(filtered["observation"]).to eq("Unrelated observation")
    expect(filtered["supportive_action"]).to eq("Unrelated support plan")
  end
end
