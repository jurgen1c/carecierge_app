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
      "extracted_memory" => {
        "decision" => "correct",
        "corrected_title" => "Private corrected title",
        "corrected_body" => "Private corrected memory"
      },
      "mood_note" => {
        "category" => "stressed",
        "observation" => "Private mood observation",
        "supportive_action" => "Private support plan"
      },
      "reminder" => {
        "title" => "Call David",
        "notes" => "Private context for the conversation"
      },
      "commitment" => {
        "title" => "Send David the report",
        "notes" => "Private promise context"
      },
      "interaction" => {
        "interaction_type" => "call",
        "notes" => "Private relationship context"
      },
      "message_draft" => {
        "content" => "Private personal message",
        "situation" => "Private incoming message",
        "tone" => "warm"
      },
      "privacy_vault_unlock" => {
        "password" => "vault-password"
      },
      "memory_query" => "Private relationship search",
      "body" => "Unrelated body",
      "transcript" => "Unrelated transcript",
      "observation" => "Unrelated observation",
      "supportive_action" => "Unrelated support plan",
      "notes" => "Unrelated notes"
    )

    expect(filtered.dig("conversation_recap", "body")).to eq("[FILTERED]")
    expect(filtered.dig("conversation_recap", "transcript")).to eq("[FILTERED]")
    expect(filtered.dig("conversation_recap", "title")).to eq("Lunch with David")
    expect(filtered.dig("extracted_memory", "corrected_title")).to eq("[FILTERED]")
    expect(filtered.dig("extracted_memory", "corrected_body")).to eq("[FILTERED]")
    expect(filtered.dig("extracted_memory", "decision")).to eq("correct")
    expect(filtered.dig("mood_note", "observation")).to eq("[FILTERED]")
    expect(filtered.dig("mood_note", "supportive_action")).to eq("[FILTERED]")
    expect(filtered.dig("mood_note", "category")).to eq("stressed")
    expect(filtered.dig("reminder", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("reminder", "title")).to eq("Call David")
    expect(filtered.dig("commitment", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("commitment", "title")).to eq("Send David the report")
    expect(filtered.dig("interaction", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("interaction", "interaction_type")).to eq("call")
    expect(filtered.dig("message_draft", "content")).to eq("[FILTERED]")
    expect(filtered.dig("message_draft", "situation")).to eq("[FILTERED]")
    expect(filtered.dig("message_draft", "tone")).to eq("warm")
    expect(filtered.dig("privacy_vault_unlock", "password")).to eq("[FILTERED]")
    expect(filtered["memory_query"]).to eq("[FILTERED]")
    expect(filtered["body"]).to eq("Unrelated body")
    expect(filtered["transcript"]).to eq("Unrelated transcript")
    expect(filtered["observation"]).to eq("Unrelated observation")
    expect(filtered["supportive_action"]).to eq("Unrelated support plan")
    expect(filtered["notes"]).to eq("Unrelated notes")
    expect(filter.filter_param("situation", "Private incoming message")).to eq("[FILTERED]")
  end
end
