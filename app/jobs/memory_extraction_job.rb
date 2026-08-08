class MemoryExtractionJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(conversation_recap)
    unless FeatureFlag.enabled?(
      "ai_memory_extraction",
      user: conversation_recap.relationship_profile.user,
      environment: Rails.env
    )
      mark_retryable(conversation_recap)
      return
    end

    MemoryExtractions::Extract.call(conversation_recap:)
  end

  private

  def mark_retryable(conversation_recap)
    conversation_recap.with_lock do
      return unless conversation_recap.extraction_status == "requested"

      conversation_recap.update!(
        extraction_status: "failed",
        extraction_completed_at: Time.current,
        extraction_error_code: "feature_disabled"
      )
    end
  end
end
