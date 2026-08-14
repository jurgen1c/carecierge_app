# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :memory_query, :situation,
  "conversation_recap.body", "conversation_recap.transcript",
  "extracted_memory.corrected_title", "extracted_memory.corrected_body",
  "message_draft.content", "message_draft.situation",
  "social_context_note.body", "social_context_note.interpretation",
  "mood_note.observation", "mood_note.supportive_action",
  "reminder.notes", "commitment.notes", "interaction.notes",
  "data_deletion.confirmation"
]
