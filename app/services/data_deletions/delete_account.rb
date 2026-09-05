module DataDeletions
  class DeleteAccount
    CalendarRevocationError = Class.new(StandardError)

    def self.call(user:)
      new(user:).call
    end

    def initialize(user:)
      @user = user
      @calendar_revoked = false
    end

    def call
      blobs = []

      Perform.call(
        user:,
        request_kind: "account",
        after_commit: -> { DeleteBlobs.call(blobs) },
        after_rollback: ->(error) { compensate_calendar_failure!(error) }
      ) do
        disconnect_contacts!
        revoke_pending_calendar_credentials!
        disconnect_calendar!
        profiles = locked_profiles
        blobs = deletion_blobs(profiles)
        FeatureFlagAssignment.where(target_kind: "user", target_value: user.id).delete_all
        user.destroy!
      end
    end

    private

    attr_reader :user

    def disconnect_contacts!
      return unless user.contacts_connection
      if Contacts::Disconnect.call(user:, after_revoke: -> { @contacts_revoked = true })
        @contacts_revoked = true
      else
        @contacts_revocation_failed = !@contacts_revoked
        raise CalendarRevocationError, "Contacts access could not be revoked"
      end
    end

    def compensate_contacts_failure!
      connection = ContactsConnection.lock.find_by(user_id: user.id)
      return unless connection
      if @contacts_revocation_failed || @contacts_revoked
        user.increment!(:contacts_connection_generation)
        connection.update!(status: @contacts_revocation_failed ? "cleanup_required" : "authorization_required")
      end
    end

    def disconnect_calendar!
      connection = user.calendar_connection
      return unless connection
      if CalendarConnections::Disconnect.call(connection:, actor: user, after_revoke: -> { @calendar_revoked = true })
        return
      end

      @calendar_revocation_failed = true
      raise CalendarRevocationError, "Calendar access could not be revoked"
    end

    def revoke_pending_calendar_credentials!
      user.calendar_credential_revocations.order(:id).lock.each do |revocation|
        CalendarConnections::GoogleOauth.revoke(credentials: revocation.credentials)
        revocation.destroy!
      rescue CalendarConnections::ConnectionError => error
        @pending_revocation_failure = [ revocation.id, error.code ]
        raise CalendarRevocationError, "Pending calendar access could not be revoked"
      end
    end

    def record_pending_calendar_revocation_failure!
      return unless @pending_revocation_failure

      revocation_id, code = @pending_revocation_failure
      CalendarCredentialRevocation.lock.find_by(id: revocation_id)&.record_failure!(code)
    end

    def calendar_revoked? = @calendar_revoked

    def compensate_calendar_failure!(error)
      compensate_contacts_failure!
      if error.is_a?(CalendarRevocationError)
        record_pending_calendar_revocation_failure!
        record_calendar_revocation_failure! if @calendar_revocation_failed
      elsif calendar_revoked?
        record_completed_calendar_revocation!
      end
    end

    def record_completed_calendar_revocation!
      connection = CalendarConnection.lock.find_by(user_id: user.id)
      return unless connection

      user.increment!(:calendar_connection_generation)
      connection.update!(
        sync_status: "action_required",
        sync_lease_token: nil,
        sync_lease_expires_at: nil,
        resync_requested: false,
        last_error_at: Time.current,
        last_error_code: "authorization_required"
      )
      AuditEvent.record!(
        user:,
        actor: user,
        action: "calendar.connection.revoked",
        target: user,
        metadata: { result: "success" }
      )
    end

    def record_calendar_revocation_failure!
      connection = CalendarConnection.lock.find_by(user_id: user.id)
      return unless connection

      connection.update!(
        sync_status: "failed",
        sync_lease_token: nil,
        sync_lease_expires_at: nil,
        resync_requested: false,
        last_error_at: Time.current,
        last_error_code: "revocation_failed"
      )
      AuditEvent.record!(
        user:,
        actor: user,
        action: "calendar.connection.revocation_failed",
        target: connection,
        metadata: { result: "revocation_failed" }
      )
    end

    def locked_profiles
      user.relationship_profiles.with_discarded.order(:id).lock.to_a
    end

    def deletion_blobs(profiles)
      (recording_blobs(profiles) + social_context_blobs(profiles) + owner_stamped_blobs).uniq(&:id)
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

    def owner_stamped_blobs
      ActiveStorage::Blob.where(uploaded_by_user_id: user.id).to_a
    end
  end
end
