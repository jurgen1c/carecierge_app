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
      "approval_request" => {
        "decision" => "edit",
        "corrected_title" => "Private queue correction",
        "corrected_body" => "Private queue memory"
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
      "relationship_briefing" => {
        "interaction_context" => "Private plans for an upcoming dinner",
        "include_private_notes" => "1"
      },
      "gift_recommendation" => {
        "occasion" => "Private details about a milestone",
        "allow_repeats" => "1"
      },
      "social_context_note" => {
        "body" => "Private social context",
        "interpretation" => "Private AI interpretation",
        "allow_suggestions" => "1"
      },
      "event_plan" => {
        "title" => "Private celebration title",
        "guest_list" => "Private guest list",
        "notes" => "Private planning notes",
        "occasion_type" => "birthday"
      },
      "vendor" => {
        "name" => "Private vendor lead",
        "location" => "Near Maya's home",
        "minimum_price" => "125",
        "maximum_price" => "300",
        "availability" => "Saturday evening",
        "occasion_types" => [ "birthday" ],
        "preference_tags_text" => "wheelchair accessible, quiet",
        "fit_notes" => "Private relationship context",
        "source_name" => "Personal referral",
        "source_url" => "https://private-user:secret@example.com/vendor",
        "source_kind" => "external"
      },
      "vendor_search" => {
        "query" => "private dinner",
        "category" => "restaurant",
        "location" => "Near Maya's home",
        "occasion_type" => "birthday",
        "preference" => "quiet",
        "maximum_budget" => "300",
        "timing" => "Saturday evening"
      },
      "vendor_shortlist" => {
        "title" => "Private birthday dinner options",
        "relationship_profile_id" => SecureRandom.uuid
      },
      "vendor_option" => {
        "notes" => "Private comparison notes",
        "constraints" => "Private family constraint",
        "next_action" => "Private next step",
        "vendor_id" => SecureRandom.uuid
      },
      "vendor_quote" => {
        "amount" => "1250.00",
        "currency" => "USD",
        "scope_details" => "Private event scope",
        "next_action" => "Confirm the deposit",
        "notes" => "Private quote notes"
      },
      "plan_task" => {
        "title" => "Private planning step",
        "details" => "Private step details",
        "phase" => "arrange"
      },
      "personal_touch_item" => {
        "title" => "Private personal gesture",
        "details" => "Private relationship context",
        "category" => "message"
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
    expect(filtered.dig("approval_request", "corrected_title")).to eq("[FILTERED]")
    expect(filtered.dig("approval_request", "corrected_body")).to eq("[FILTERED]")
    expect(filtered.dig("approval_request", "decision")).to eq("edit")
    expect(filtered.dig("mood_note", "observation")).to eq("[FILTERED]")
    expect(filtered.dig("mood_note", "supportive_action")).to eq("[FILTERED]")
    expect(filtered.dig("mood_note", "category")).to eq("stressed")
    expect(filtered.dig("reminder", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("reminder", "title")).to eq("[FILTERED]")
    expect(filtered.dig("vendor_quote", "amount")).to eq("[FILTERED]")
    expect(filtered.dig("vendor_quote", "scope_details")).to eq("[FILTERED]")
    expect(filtered.dig("vendor_quote", "next_action")).to eq("[FILTERED]")
    expect(filtered.dig("vendor_quote", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("vendor_quote", "currency")).to eq("USD")
    expect(filtered.dig("commitment", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("commitment", "title")).to eq("Send David the report")
    expect(filtered.dig("interaction", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("interaction", "interaction_type")).to eq("call")
    expect(filtered.dig("message_draft", "content")).to eq("[FILTERED]")
    expect(filtered.dig("message_draft", "situation")).to eq("[FILTERED]")
    expect(filtered.dig("message_draft", "tone")).to eq("warm")
    expect(filtered.dig("relationship_briefing", "interaction_context")).to eq("[FILTERED]")
    expect(filtered.dig("relationship_briefing", "include_private_notes")).to eq("1")
    expect(filtered.dig("gift_recommendation", "occasion")).to eq("[FILTERED]")
    expect(filtered.dig("gift_recommendation", "allow_repeats")).to eq("1")
    expect(filtered.dig("social_context_note", "body")).to eq("[FILTERED]")
    expect(filtered.dig("social_context_note", "interpretation")).to eq("[FILTERED]")
    expect(filtered.dig("social_context_note", "allow_suggestions")).to eq("1")
    expect(filtered.dig("event_plan", "title")).to eq("[FILTERED]")
    expect(filtered.dig("event_plan", "guest_list")).to eq("[FILTERED]")
    expect(filtered.dig("event_plan", "notes")).to eq("[FILTERED]")
    expect(filtered.dig("event_plan", "occasion_type")).to eq("birthday")
    expect(filtered.fetch("vendor").except("source_kind").values).to all(eq("[FILTERED]"))
    expect(filtered.dig("vendor", "source_kind")).to eq("external")
    expect(filtered.fetch("vendor_search").values).to all(eq("[FILTERED]"))
    expect(filtered.dig("vendor_shortlist", "title")).to eq("[FILTERED]")
    expect(filtered.dig("vendor_shortlist", "relationship_profile_id")).not_to eq("[FILTERED]")
    expect(filtered.fetch("vendor_option").except("vendor_id").values).to all(eq("[FILTERED]"))
    expect(filtered.dig("vendor_option", "vendor_id")).not_to eq("[FILTERED]")
    expect(filtered.dig("plan_task", "title")).to eq("[FILTERED]")
    expect(filtered.dig("plan_task", "details")).to eq("[FILTERED]")
    expect(filtered.dig("plan_task", "phase")).to eq("arrange")
    expect(filtered.dig("personal_touch_item", "title")).to eq("[FILTERED]")
    expect(filtered.dig("personal_touch_item", "details")).to eq("[FILTERED]")
    expect(filtered.dig("personal_touch_item", "category")).to eq("message")
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
