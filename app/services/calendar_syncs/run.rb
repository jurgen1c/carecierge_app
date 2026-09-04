module CalendarSyncs
  class Run
    LEASE_DURATION = 20.minutes
    MAX_EVENT_ID_PROBES = 10
    LeaseLost = Class.new(StandardError)

    def self.call(connection:, owner_requested: false)
      new(connection:, owner_requested:).call
    end

    def initialize(connection:, owner_requested:)
      @connection = connection
      @owner_requested = owner_requested
      @retryable_error = nil
    end

    def call
      ActiveSupport::Notifications.instrument("sync.calendar", connection_id: connection.id) do |payload|
        if begin_sync
          reconcile!
          with_owner_boundary do
            if permission_blocked?
              record_failure(
                CalendarProviders::AuthorizationError.new(code: "calendar_permission_required"),
                status: "failed"
              )
              payload[:status] = "calendar_permission_required"
            else
              finish_sync!
              payload[:status] = "success"
            end
            payload[:count] = changed_count
          end
        else
          payload[:status] = "skipped"
        end
      rescue LeaseLost, CalendarProviders::LeaseLostError
        payload[:status] = "lease_lost"
      rescue CalendarProviders::AuthorizationError => error
        record_failure(error, status: "action_required")
        payload[:status] = "authorization_required"
      rescue CalendarProviders::TransientError => error
        record_failure(error, status: "failed")
        payload[:status] = error.code
        @retryable_error = error
      rescue CalendarProviders::PermanentError => error
        record_failure(error, status: "failed")
        payload[:status] = error.code
      end
      raise retryable_error if retryable_error

      connection
    end

    private

    attr_reader :connection, :owner_requested, :retryable_error

    def begin_sync
      started = false
      connection.user.with_lock do
        connection.with_lock do
          next unless connection.syncable?(owner_requested:)

          @lease_token = SecureRandom.uuid
          @sync_types = connection.sync_types.dup
          connection.update!(
            sync_status: "syncing",
            sync_lease_token: lease_token,
            sync_lease_expires_at: LEASE_DURATION.from_now,
            resync_requested: false,
            last_sync_started_at: Time.current,
            last_error_at: nil,
            last_error_code: nil
          )
          started = true
        end
      end
      started
    end

    def calendar_access_permitted?(source = nil)
      relationship = CalendarSyncs::SourceRelationship.resolve(source)
      return false unless relationship.eligible

      AutomationPermission.decision_for(
        user: connection.user,
        capability: "access_calendar",
        relationship_profile: relationship.profile
      )
        .permits_execution?(explicitly_approved: owner_requested)
    end

    def reconcile!
      connection.sync_types = sync_types
      desired = CalendarSyncs::Sources.for(connection).index_by { |source| [ source.class.base_class.name, source.id ] }
      mappings = connection.calendar_event_syncs.reset.index_by { |mapping| [ mapping.source_type, mapping.source_id ] }

      desired.each_value { |source| sync_source(source, mappings[[ source.class.base_class.name, source.id ]]) }
      mappings.except(*desired.keys).each_value { |mapping| remove_mapping(mapping) }
      connection.calendar_event_syncs.reset
    end

    def sync_source(source, mapping)
      with_owner_boundary do
        source = revalidated_source(source)
        unless source
          remove_mapping(mapping) if mapping
          return
        end
        return unless with_calendar_access(source) { true }

        event = CalendarSyncs::Event.new(source:, locale: connection.locale)
        synchronized = if mapping
          return if mapping.synced_at? && mapping.source_fingerprint == event.fingerprint
          sync_existing_mapping(mapping, event, source)
        else
          publish_new_mapping(source, event)
        end
        return unless synchronized

        @changed_count = changed_count + 1
      end
    end

    def revalidated_source(source)
      fresh_source = source.class.base_class.unscoped.find_by(id: source.id)
      return unless fresh_source

      initial_relationship = CalendarSyncs::SourceRelationship.resolve(fresh_source)
      profile_ids = initial_relationship.profiles.map(&:id).sort
      locked_profile_ids = connection.user.relationship_profiles.with_discarded
        .where(id: profile_ids)
        .order(:id)
        .lock
        .pluck(:id)
        .sort
      return unless locked_profile_ids == profile_ids

      fresh_source.lock!
      relationship = CalendarSyncs::SourceRelationship.resolve(fresh_source)
      return unless relationship.profiles.map(&:id).sort == profile_ids
      return unless relationship.eligible && source_owned_and_eligible?(fresh_source)

      fresh_source
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def source_owned_and_eligible?(source)
      return false unless sync_types.include?(CalendarSyncs::Event::SYNC_TYPE_BY_CLASS.fetch(source.class.base_class.name))

      case source
      when ImportantDate
        source.relationship_profile.user_id == connection.user_id
      when Reminder
        source.user_id == connection.user_id && source.active?
      when EventPlan
        source.user_id == connection.user_id && !source.archived? && source.starts_on.present?
      when Booking
        source.user_id == connection.user_id && !source.status.in?(%w[cancelled completed])
      when Commitment
        source.relationship_profile.user_id == connection.user_id && source.open? && source.due_on.present?
      else
        false
      end
    end

    def remove_mapping(mapping)
      with_owner_boundary do
        renew_lease!
        provider.delete_event(mapping.external_event_id)
        renew_lease!
        mapping.destroy!
        mark_audit_pending!
      end
      @changed_count = changed_count + 1
    end

    def provider
      @provider ||= CalendarProviders::Google.new(connection:)
    end

    def sync_existing_mapping(mapping, event, source)
      with_calendar_access(source) do
        renew_lease!
        if mapping.synced_at.nil?
          provider.create_event(event.attributes, event_id: mapping.external_event_id)
        else
          provider.update_event(mapping.external_event_id, event.attributes)
        end
        renew_lease!
        mapping.update!(source_fingerprint: event.fingerprint, synced_at: Time.current)
        mark_audit_pending!
      end
    rescue CalendarProviders::NotFoundError
      advance_mapping_event_id!(mapping, event)
      publish_mapping(mapping, event, source)
    end

    def publish_new_mapping(source, event)
      mapping = nil
      permitted = with_calendar_access(source) do
        mapping = connection.calendar_event_syncs.create!(
          id: SecureRandom.uuid,
          source:,
          external_event_id: provider_event_id(source),
          source_fingerprint: event.fingerprint,
          synced_at: nil
        )
        renew_lease!
        provider.create_event(event.attributes, event_id: mapping.external_event_id)
        renew_lease!
        mapping.update!(synced_at: Time.current)
        mark_audit_pending!
      end
      permitted ? mapping : nil
    rescue CalendarProviders::NotFoundError
      advance_mapping_event_id!(mapping, event)
      publish_mapping(mapping, event, source) ? mapping : nil
    end

    def publish_mapping(mapping, event, source)
      probes = 0
      begin
        with_calendar_access(source) do
          renew_lease!
          provider.create_event(event.attributes, event_id: mapping.external_event_id)
          renew_lease!
          mapping.update!(source_fingerprint: event.fingerprint, synced_at: Time.current)
          mark_audit_pending!
        end
      rescue CalendarProviders::NotFoundError
        probes += 1
        raise CalendarProviders::PermanentError.new(code: "provider_rejected") if probes >= MAX_EVENT_ID_PROBES

        advance_mapping_event_id!(mapping, event)
        retry
      end
    end

    def advance_mapping_event_id!(mapping, event)
      with_owner_boundary do
        renew_lease!
        replacement_id = Digest::SHA256.hexdigest([ mapping.external_event_id, "replacement" ].join(":"))
        mapping.update!(external_event_id: replacement_id, source_fingerprint: event.fingerprint, synced_at: nil)
      end
    end

    def with_calendar_access(source)
      with_owner_boundary do
        unless calendar_access_permitted?(source)
          @permission_blocked = true
          next false
        end

        yield
        true
      end
    end

    def with_owner_boundary
      return yield if @owner_boundary_held

      deferred_error = nil
      result = connection.user.with_lock do
        @owner_boundary_held = true
        begin
          yield
        ensure
          @owner_boundary_held = false
        end
      rescue CalendarProviders::Error, LeaseLost => error
        deferred_error = error
        nil
      end
      raise deferred_error if deferred_error

      result
    end

    def provider_event_id(source)
      Digest::SHA256.hexdigest([ connection.user_id, source.class.base_class.name, source.id ].join(":"))
    end

    def finish_sync!
      resync_requested = false
      connection.with_lock do
        next unless owns_lease?

        resync_requested = connection.resync_requested?
        create_audit!("calendar.sync.completed", count: connection.pending_audit_count, result: "success") if connection.pending_audit_count.positive?
        connection.update!(
          sync_status: "connected",
          sync_lease_token: nil,
          sync_lease_expires_at: nil,
          resync_requested: false,
          pending_audit_count: 0,
          last_synced_at: Time.current
        )
      end
      CalendarSyncJob.perform_later(connection, owner_requested: true) if resync_requested
    end

    def mark_audit_pending!
      connection.increment!(:pending_audit_count)
    end

    def renew_lease!
      expires_at = LEASE_DURATION.from_now
      updated_count = CalendarConnection.where(id: connection.id, sync_lease_token: lease_token)
        .update_all([ "sync_lease_expires_at = ?", expires_at ])
      raise LeaseLost unless updated_count == 1

      connection.reload
    end

    def owns_lease? = connection.sync_lease_token == lease_token
    attr_reader :lease_token, :sync_types

    def changed_count = @changed_count ||= 0
    def permission_blocked? = @permission_blocked == true

    def record_failure(error, status:)
      safe_code = error.code.to_s.in?(CalendarConnection::ERROR_CODES) ? error.code : "provider_error"
      recorded = false
      resync_requested = false
      with_owner_boundary do
        connection.with_lock do
          next unless owns_lease?

          resync_requested = connection.resync_requested?
          connection.update!(
            sync_status: status,
            sync_lease_token: nil,
            sync_lease_expires_at: nil,
            resync_requested: false,
            last_error_at: Time.current,
            last_error_code: safe_code
          )
          recorded = true
        end
      end
      record_audit("calendar.sync.failed", result: safe_code) if recorded
      CalendarSyncJob.perform_later(connection, owner_requested: true) if recorded && resync_requested
    end

    def record_audit(action, metadata)
      connection.user.with_lock do
        create_audit!(action, metadata)
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end


    def create_audit!(action, metadata)
      AuditEvent.record!(
        user: connection.user,
        actor: nil,
        actor_kind: "system",
        source: "system",
        action:,
        target: connection,
        metadata:
      )
    end
  end
end
