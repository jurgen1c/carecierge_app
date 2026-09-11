module ConversationRecaps
  class RetryExtraction
    def self.call(recap)
      requested = recap.with_lock do
        next false unless recap.extraction_status == "failed"

        recap.update!(extraction_status: "requested", extraction_requested_at: Time.current,
          extraction_started_at: nil, extraction_completed_at: nil, extraction_error_code: nil)
        true
      end
      MemoryExtractionJob.perform_later(recap) if requested
      requested
    end
  end
end
