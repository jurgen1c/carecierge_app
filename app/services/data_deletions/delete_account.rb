module DataDeletions
  class DeleteAccount
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      blobs = attached_recording_blobs

      Perform.call(
        user:,
        request_kind: "account",
        after_commit: -> { delete_recording_blobs(blobs) }
      ) do
        FeatureFlagAssignment.where(target_kind: "user", target_value: user.id).delete_all
        user.destroy!
      end
    end

    private

    attr_reader :user

    def attached_recording_blobs
      ConversationRecap
        .where(relationship_profile: user.relationship_profiles.with_discarded)
        .with_attached_audio_recording
        .filter_map { |recap| recap.audio_recording.blob if recap.audio_recording.attached? }
        .uniq(&:id)
    end

    def delete_recording_blobs(blobs)
      blobs.each { |blob| delete_recording_blob(blob) }
    end

    def delete_recording_blob(blob)
      blob.with_lock do
        return if blob.attachments.exists?

        blob.delete
        blob.destroy!
      end
    rescue ActiveRecord::RecordNotFound
      blob.delete
    end
  end
end
