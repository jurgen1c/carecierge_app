module DataDeletions
  class Perform
    def self.call(user:, request_kind:, subject: nil, after_commit: nil, after_rollback: nil, &mutation)
      new(user:, request_kind:, subject:, after_commit:, after_rollback:).call(&mutation)
    end

    def initialize(user:, request_kind:, subject: nil, after_commit: nil, after_rollback: nil)
      @user = user
      @request_kind = request_kind
      @subject = subject
      @after_commit = after_commit
      @after_rollback = after_rollback
    end

    def call(&mutation)
      deletion_request = create_request!
      mutation_error = nil

      ApplicationRecord.transaction do
        with_owner_lock do
          if after_rollback
            begin
              ApplicationRecord.transaction(requires_new: true) { perform_mutation(&mutation) }
            rescue StandardError => error
              after_rollback.call(error)
              mutation_error = error
            end
          else
            perform_mutation(&mutation)
          end
        end
      end
      raise mutation_error if mutation_error

      after_commit&.call
      deletion_request.update!(status: "completed", completed_at: Time.current)

      deletion_request
    rescue StandardError
      deletion_request&.update_columns(status: "failed", updated_at: Time.current)
      raise
    end

    private

    attr_reader :user, :request_kind, :subject, :after_commit, :after_rollback

    def with_owner_lock(&block)
      return user.with_lock(&block) if request_kind == "account"

      user.with_lock("FOR NO KEY UPDATE", &block)
    end

    def perform_mutation
      AuditEvent.record!(
        user:,
        actor: user,
        action: "data_deletion.requested",
        metadata: { request_kind:, result: "completed" }
      )
      yield
    end

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
