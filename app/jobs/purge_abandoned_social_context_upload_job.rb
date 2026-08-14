class PurgeAbandonedSocialContextUploadJob < ApplicationJob
  GRANT_TTL = 10.minutes
  RETENTION_PERIOD = 1.hour

  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(blob_id, user_id)
    user = User.find_by(id: user_id)
    return unless user

    user.with_lock do
      blob = ActiveStorage::Blob.find_by(id: blob_id)
      return unless blob

      blob.with_lock do
        return unless blob.uploaded_by_user_id == user.id
        return if blob.created_at > RETENTION_PERIOD.ago
        return if blob.attachments.exists?

        blob.delete
        blob.destroy!
      end
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
