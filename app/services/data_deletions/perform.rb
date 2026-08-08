module DataDeletions
  class Perform
    def self.call(user:, request_kind:, subject: nil, after_commit: nil, &mutation)
      new(user:, request_kind:, subject:, after_commit:).call(&mutation)
    end

    def initialize(user:, request_kind:, subject: nil, after_commit: nil)
      @user = user
      @request_kind = request_kind
      @subject = subject
      @after_commit = after_commit
    end

    def call
      deletion_request = create_request!

      ApplicationRecord.transaction do
        user.with_lock do
          AuditEvent.record!(
            user:,
            actor: user,
            action: "data_deletion.requested",
            metadata: { request_kind:, result: "completed" }
          )
          yield
        end
      end

      after_commit&.call
      deletion_request.update!(status: "completed", completed_at: Time.current)

      deletion_request
    rescue StandardError
      deletion_request&.update_columns(status: "failed", updated_at: Time.current)
      raise
    end

    private

    attr_reader :user, :request_kind, :subject, :after_commit

    def create_request!
      DeletionRequest.create!(
        user:,
        request_kind:,
        account_digest: OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, user.id),
        subject_type: subject&.class&.base_class&.name,
        subject_id: subject&.id,
        requested_at: Time.current
      )
    end
  end
end
