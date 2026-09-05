# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :memory_query, :situation,
  :messaging_query, :external_id, :reply_draft, :context_id,
  :code, :state, "calendar_connection.sync_types",
  "conversation_recap.body", "conversation_recap.transcript",
  "extracted_memory.corrected_title", "extracted_memory.corrected_body",
  "approval_request.corrected_title", "approval_request.corrected_body",
  "message_draft.content", "message_draft.situation",
  "relationship_briefing.interaction_context",
  "gift_recommendation.occasion",
  "event_plan.title", "event_plan.guest_list", "event_plan.notes",
  "vendor.name", "vendor.location", "vendor.minimum_price", "vendor.maximum_price",
  "vendor.availability", "vendor.occasion_types", "vendor.occasion_types_text",
  "vendor.preference_tags", "vendor.preference_tags_text", "vendor.fit_notes",
  "vendor.source_name", "vendor.source_url",
  "vendor_shortlist.title", "vendor_option.notes", "vendor_option.constraints", "vendor_option.next_action",
  "vendor_quote.amount", "vendor_quote.scope_details", "vendor_quote.next_action", "vendor_quote.notes",
  "booking.title", "booking.provider_name", "booking.starts_at", "booking.time_zone", "booking.location", "booking.confirmation_details",
  "booking.cancellation_policy", "booking.notes",
  "vendor_search.query", "vendor_search.category", "vendor_search.location",
  "vendor_search.occasion_type", "vendor_search.preference", "vendor_search.maximum_budget",
  "vendor_search.timing",
  "plan_task.title", "plan_task.details", "reminder.title",
  "personal_touch_item.title", "personal_touch_item.details",
  "social_context_note.body", "social_context_note.interpretation",
  "mood_note.observation", "mood_note.supportive_action",
  "reminder.notes", "commitment.notes", "interaction.notes",
  "data_deletion.confirmation"
]

Rails.application.config.filter_parameters += [ :contacts, :contacts_oauth_nonce, :next_page_token, :external_id ]
