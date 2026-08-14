module DataDeletions
  class DeleteAccount
    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
    end

    def call
      blobs = []

      Perform.call(
        user:,
        request_kind: "account",
        after_commit: -> { DeleteBlobs.call(blobs) }
      ) do
        profiles = locked_profiles
        blobs = attached_blobs(profiles)
        FeatureFlagAssignment.where(target_kind: "user", target_value: user.id).delete_all
        user.destroy!
      end
    end

    private

    attr_reader :user

    def locked_profiles
      user.relationship_profiles.with_discarded.order(:id).lock.to_a
    end

    def attached_blobs(profiles)
      (recording_blobs(profiles) + social_context_blobs(profiles)).uniq(&:id)
    end

    def recording_blobs(profiles)
      ConversationRecap
        .where(relationship_profile: profiles)
        .with_attached_audio_recording
        .filter_map { |recap| recap.audio_recording.blob if recap.audio_recording.attached? }
        .uniq(&:id)
    end

    def social_context_blobs(profiles)
      SocialContextNote
        .where(relationship_profile: profiles)
        .with_rich_text_body_and_embeds
        .flat_map(&:image_blobs)
    end
  end
end
