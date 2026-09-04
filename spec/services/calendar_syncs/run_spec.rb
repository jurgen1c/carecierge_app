require "rails_helper"

RSpec.describe CalendarSyncs::Run do
  let(:connection) { create(:calendar_connection) }
  let(:user) { connection.user }
  let(:profile) { create(:relationship_profile, user:) }
  let(:provider) { instance_double(CalendarProviders::Google) }

  before do
    create(:automation_permission, user:, capability: "access_calendar", mode: "allow_automatically")
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
    allow(provider).to receive(:create_event) { |event, event_id:| event_id }
    allow(provider).to receive(:update_event)
    allow(provider).to receive(:delete_event)
  end

  it "fails closed before provider writes when calendar access is disabled" do
    user.automation_permissions.find_by!(capability: "access_calendar").update!(mode: "disabled")
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])

    described_class.call(connection:, owner_requested: true)

    expect(provider).not_to have_received(:create_event)
    expect(connection.calendar_event_syncs.find_by(source: reminder)).to be_nil
    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      last_error_code: "calendar_permission_required",
      last_synced_at: nil
    )
  end

  it "requires an explicit owner request when calendar access asks every time" do
    user.automation_permissions.find_by!(capability: "access_calendar").update!(mode: "ask_every_time")
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])

    described_class.call(connection:)
    expect(provider).not_to have_received(:create_event)

    described_class.call(connection:, owner_requested: true)

    expect(provider).to have_received(:create_event).once
    expect(connection.calendar_event_syncs.find_by(source: reminder)).to be_present
  end

  it "honors relationship overrides before sending each source to the provider" do
    blocked_profile = create(:relationship_profile, user:)
    allowed_reminder = create(:reminder, user:, relationship_profile: profile)
    blocked_reminder = create(:reminder, user:, relationship_profile: blocked_profile)
    create(
      :automation_permission,
      user:,
      relationship_profile: blocked_profile,
      capability: "access_calendar",
      mode: "disabled"
    )
    connection.update!(sync_types: [ "reminders" ])

    described_class.call(connection:)

    expect(provider).to have_received(:create_event).once
    expect(connection.calendar_event_syncs.find_by(source: allowed_reminder)).to be_present
    expect(connection.calendar_event_syncs.find_by(source: blocked_reminder)).to be_nil
  end

  it "derives a reminder relationship from its attachment before checking permission" do
    important_date = create(:important_date, relationship_profile: profile)
    reminder = create(:reminder, user:, relationship_profile: nil, important_date:)
    create(
      :automation_permission,
      user:,
      relationship_profile: profile,
      capability: "access_calendar",
      mode: "disabled"
    )
    connection.update!(sync_types: [ "reminders" ])

    described_class.call(connection:)

    expect(provider).not_to have_received(:create_event)
    expect(connection.calendar_event_syncs.find_by(source: reminder)).to be_nil
    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      last_error_code: "calendar_permission_required"
    )
  end

  it "rechecks calendar permission before later provider writes" do
    first_reminder = create(:reminder, user:, relationship_profile: profile)
    second_reminder = create(:reminder, user:, relationship_profile: profile)
    permission = user.automation_permissions.find_by!(capability: "access_calendar")
    connection.update!(sync_types: [ "reminders" ])

    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      permission.update!(mode: "disabled")
      event_id
    end

    described_class.call(connection:)

    expect(provider).to have_received(:create_event).once
    expect(connection.calendar_event_syncs.where(source: [ first_reminder, second_reminder ]).count).to eq(1)
  end

  it "uses a fresh owner-lock boundary for each provider write" do
    create_list(:reminder, 2, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    owner_lock_sequence = 0
    provider_write_sequences = []
    allow(connection).to receive(:user).and_return(user)
    allow(user).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      owner_lock_sequence += 1
      original.call(*args, &block)
    end
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      provider_write_sequences << owner_lock_sequence
      event_id
    end

    described_class.call(connection:)

    expect(provider_write_sequences).to eq([ 2, 3 ])
  end

  it "keeps the in-memory lease expiry current after renewal" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    initial_expiry = 5.minutes.from_now
    renewed_expiry = 20.minutes.from_now
    allow(described_class::LEASE_DURATION).to receive(:from_now).and_return(
      initial_expiry,
      renewed_expiry,
      renewed_expiry
    )
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      expect(connection.sync_lease_expires_at).to be_within(0.000001).of(renewed_expiry)
      event_id
    end

    described_class.call(connection:)

    expect(connection.calendar_event_syncs.find_by(source: reminder)).to be_present
  end

  it "queues a settings resync that was requested before a later permission failure" do
    create_list(:reminder, 2, user:, relationship_profile: profile)
    permission = user.automation_permissions.find_by!(capability: "access_calendar")
    connection.update!(sync_types: [ "reminders" ])
    settings_changed = false
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      unless settings_changed
        settings_changed = true
        CalendarConnections::UpdateSettings.call(
          connection: CalendarConnection.find(connection.id),
          sync_types: [],
          actor: user
        )
        permission.update!(mode: "disabled")
      end
      event_id
    end

    described_class.call(connection:)

    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      last_error_code: "calendar_permission_required",
      resync_requested: false
    )
    expect(CalendarSyncJob).to have_been_enqueued.with(connection, owner_requested: true)
  end

  it "reports disabled permission even when the mapped event is unchanged" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    user.automation_permissions.find_by!(capability: "access_calendar").update!(mode: "disabled")

    described_class.call(connection:)

    expect(provider).to have_received(:create_event).once
    expect(connection.calendar_event_syncs.find_by!(source: reminder)).to be_present
    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      last_error_code: "calendar_permission_required"
    )
  end

  it "does not publish a source whose relationship is archived after discovery" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    allow(CalendarSyncs::Sources).to receive(:for).and_wrap_original do |original, sync_connection|
      sources = original.call(sync_connection)
      RelationshipProfile.find(profile.id).discard!
      sources
    end

    described_class.call(connection:)

    expect(provider).not_to have_received(:create_event)
    expect(connection.calendar_event_syncs.find_by(source: reminder)).to be_nil
  end

  it "does not publish a source deleted after discovery" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    allow(CalendarSyncs::Sources).to receive(:for).and_wrap_original do |original, sync_connection|
      sources = original.call(sync_connection)
      Reminder.find(reminder.id).destroy!
      sources
    end

    described_class.call(connection:)

    expect(provider).not_to have_received(:create_event)
    expect(connection.calendar_event_syncs.find_by(source_type: "Reminder", source_id: reminder.id)).to be_nil
  end

  it "creates one mapping for each selected owner-scoped source and records a content-free audit" do
    create(:important_date, relationship_profile: profile)
    create(:reminder, user:, relationship_profile: profile)
    plan = create(:event_plan, user:, relationship_profile: profile)
    create(:booking, user:, event_plan: plan)
    create(:commitment, relationship_profile: profile)
    create(:reminder)

    Timecop.freeze(Time.zone.local(2026, 9, 3, 12)) do
      expect { described_class.call(connection:) }
        .to change(connection.calendar_event_syncs, :count).by(5)
        .and change { AuditEvent.where(action: "calendar.sync.completed").count }.by(1)
    end

    expect(connection.reload).to have_attributes(sync_status: "connected", last_synced_at: Time.zone.local(2026, 9, 3, 12), last_error_code: nil)
    expect(provider).to have_received(:create_event).exactly(5).times
    expect(AuditEvent.order(:created_at).last.metadata).to eq("count" => 5, "result" => "success")
  end

  it "retries durable completion evidence when audit persistence fails" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    allow(AuditEvent).to receive(:record!).and_call_original
    allow(AuditEvent).to receive(:record!)
      .with(hash_including(action: "calendar.sync.completed"))
      .and_raise(ActiveRecord::ConnectionNotEstablished, "audit unavailable")

    expect { described_class.call(connection:) }
      .to raise_error(ActiveRecord::ConnectionNotEstablished, "audit unavailable")

    expect(connection.calendar_event_syncs.find_by(source: reminder)).to be_present
    expect(connection.reload).to have_attributes(sync_status: "syncing", pending_audit_count: 1)

    connection.update_columns(sync_lease_expires_at: 1.minute.ago)
    allow(AuditEvent).to receive(:record!).and_call_original

    expect { described_class.call(connection:) }
      .to change { AuditEvent.where(action: "calendar.sync.completed").count }.by(1)

    expect(connection.reload).to have_attributes(sync_status: "connected", pending_audit_count: 0)
    expect(AuditEvent.order(:created_at).last.metadata).to eq("count" => 1, "result" => "success")
  end

  it "increments pending audit evidence despite a concurrent optimistic-lock update" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    allow(provider).to receive(:create_event) do |_event, event_id:|
      CalendarConnection.find(connection.id).update!(locale: "es")
      event_id
    end

    expect { described_class.call(connection:) }.not_to raise_error

    expect(connection.calendar_event_syncs.find_by!(source: reminder)).to be_synced_at
    expect(connection.reload).to have_attributes(sync_status: "connected", pending_audit_count: 0, locale: "es")
    expect(AuditEvent.order(:created_at).last.metadata).to eq("count" => 1, "result" => "success")
  end

  it "does not attribute pending audit evidence after losing its lease" do
    lease_token = SecureRandom.uuid
    replacement_token = SecureRandom.uuid
    connection.update!(
      sync_status: "syncing",
      sync_lease_token: replacement_token,
      sync_lease_expires_at: 1.minute.from_now
    )
    runner = described_class.new(connection:, owner_requested: false)
    runner.instance_variable_set(:@lease_token, lease_token)

    expect { runner.send(:mark_audit_pending!) }.to raise_error(described_class::LeaseLost)
    expect(connection.reload.pending_audit_count).to eq(0)
  end

  it "updates changed events, skips unchanged events, and removes no-longer-selected events" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    commitment = create(:commitment, relationship_profile: profile)
    connection.update!(sync_types: %w[reminders commitments])
    described_class.call(connection:)
    allow(provider).to receive(:create_event).and_return("unexpected")

    reminder.update!(title: "Updated reminder")
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)

    expect(provider).to have_received(:update_event).once
    expect(provider).to have_received(:delete_event).once
    expect(connection.calendar_event_syncs.pluck(:source_type, :source_id)).to eq([ [ "Reminder", reminder.id ] ])
    expect(connection.calendar_event_syncs.where(source: commitment)).to be_empty
  end

  it "holds the owner boundary through provider cleanup and mapping removal" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    connection.update!(sync_types: [])
    baseline_transactions = CalendarConnection.connection.open_transactions
    allow(provider).to receive(:delete_event) do
      expect(CalendarConnection.connection.open_transactions).to be > baseline_transactions
    end

    described_class.call(connection:)

    expect(connection.calendar_event_syncs).to be_empty
  end

  it "removes a previously synced event after its relationship is archived" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    mapping = connection.calendar_event_syncs.find_by!(source: reminder)

    profile.discard!
    described_class.call(connection:)

    expect(provider).to have_received(:delete_event).with(mapping.external_event_id)
    expect(connection.calendar_event_syncs.find_by(id: mapping.id)).to be_nil
  end

  it "removes an attached reminder event after its derived relationship is archived" do
    important_date = create(:important_date, relationship_profile: profile)
    reminder = create(:reminder, user:, relationship_profile: nil, important_date:)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    mapping = connection.calendar_event_syncs.find_by!(source: reminder)

    profile.discard!
    described_class.call(connection:)

    expect(provider).to have_received(:delete_event).with(mapping.external_event_id)
    expect(connection.calendar_event_syncs.find_by(id: mapping.id)).to be_nil
  end

  it "reuses deterministic provider ids after disconnect and reconnect" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    original_event_id = connection.calendar_event_syncs.find_by!(source: reminder).external_event_id

    connection.destroy!
    replacement = create(:calendar_connection, user:, sync_types: [ "reminders" ])
    allow(CalendarProviders::Google).to receive(:new).with(connection: replacement).and_return(provider)
    described_class.call(connection: replacement)

    expect(replacement.calendar_event_syncs.find_by!(source: reminder).external_event_id).to eq(original_event_id)
  end

  it "recreates a provider event deleted outside Carecierge" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    mapping = connection.calendar_event_syncs.find_by!(source: reminder)
    reminder.update!(title: "Updated reminder")
    allow(provider).to receive(:update_event).and_raise(
      CalendarProviders::NotFoundError.new(code: "provider_event_missing")
    )
    allow(provider).to receive(:create_event) { |_attributes, event_id:| event_id }

    described_class.call(connection:)

    expect(mapping.reload.external_event_id).to match(/\A[0-9a-f]{64}\z/)
    expect(provider).to have_received(:create_event).with(hash_including(summary: reminder.title), event_id: mapping.external_event_id)
    expect(connection.reload.sync_status).to eq("connected")
  end

  it "rediscovers a deterministic replacement event after reconnect" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    mapping = connection.calendar_event_syncs.find_by!(source: reminder)
    original_event_id = mapping.external_event_id
    reminder.update!(title: "Updated reminder")
    allow(provider).to receive(:update_event).and_raise(
      CalendarProviders::NotFoundError.new(code: "provider_event_missing")
    )
    described_class.call(connection:)
    replacement_event_id = mapping.reload.external_event_id

    connection.destroy!
    replacement_connection = create(:calendar_connection, user:, sync_types: [ "reminders" ])
    allow(CalendarProviders::Google).to receive(:new).with(connection: replacement_connection).and_return(provider)
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      if event_id == original_event_id
        raise CalendarProviders::NotFoundError.new(code: "provider_event_missing")
      end

      event_id
    end

    described_class.call(connection: replacement_connection)

    expect(replacement_connection.calendar_event_syncs.find_by!(source: reminder).external_event_id).to eq(replacement_event_id)
  end

  it "uses a deterministic provider id so a timed-out insert is safe to retry" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    attempted_ids = []
    error = CalendarProviders::TransientError.new(code: "provider_unavailable")
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      attempted_ids << event_id
      raise error if attempted_ids.one?

      event_id
    end

    expect { described_class.call(connection:) }.to raise_error(error)
    pending_mapping = connection.calendar_event_syncs.find_by!(source: reminder)
    expect(pending_mapping.synced_at).to be_nil
    reminder.update!(title: "Changed after the ambiguous insert")
    described_class.call(connection:)

    expect(attempted_ids.length).to eq(2)
    expect(attempted_ids.uniq.one?).to be(true)
    expect(attempted_ids.first).to match(/\A[0-9a-f]{64}\z/)
    expect(provider).not_to have_received(:update_event)
    expect(pending_mapping.reload).to have_attributes(external_event_id: attempted_ids.first, synced_at: be_present)
  end

  it "commits the syncing state before calling the provider" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    observed_status = nil
    baseline_transactions = CalendarConnection.connection.open_transactions
    observed_transactions = nil
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      observed_status = CalendarConnection.find(connection.id).sync_status
      observed_transactions = CalendarConnection.connection.open_transactions
      event_id
    end

    described_class.call(connection:)

    expect(observed_status).to eq("syncing")
    expect(observed_transactions).to eq(baseline_transactions + 1)
  end

  it "renews its lease without invalidating token refresh optimistic locking" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ], token_expires_at: 1.minute.ago)
    allow(CalendarProviders::Google).to receive(:new).and_call_original
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "fresh-access",
      refresh_token: "fresh-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::GoogleOauth).to receive(:refresh).and_return(credentials)
    http = instance_double(Net::HTTP)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, { id: "provider-event" }.to_json)
    response.instance_variable_set(:@read, true)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response)

    expect { described_class.call(connection:) }.not_to raise_error

    expect(connection.reload).to have_attributes(sync_status: "connected", access_token: "fresh-access")
  end

  it "serializes refreshed credentials with settings changes during a sync" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ], token_expires_at: 1.minute.ago)
    allow(CalendarProviders::Google).to receive(:new).and_call_original
    credentials = CalendarConnections::GoogleOauth::Credentials.new(
      access_token: "fresh-access",
      refresh_token: "fresh-refresh",
      expires_at: 1.hour.from_now,
      scopes: [ CalendarConnection::GOOGLE_SCOPE ]
    )
    allow(CalendarConnections::GoogleOauth).to receive(:refresh) do
      concurrent_connection = CalendarConnection.find(connection.id)
      CalendarConnections::UpdateSettings.call(connection: concurrent_connection, sync_types: [ "commitments" ], actor: user)
      credentials
    end
    http = instance_double(Net::HTTP)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@body, { id: "provider-event" }.to_json)
    response.instance_variable_set(:@read, true)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response)

    expect { described_class.call(connection:) }.not_to raise_error

    expect(connection.reload).to have_attributes(access_token: "fresh-access", sync_types: [ "commitments" ])
    expect(CalendarSyncJob).to have_been_enqueued.with(connection, owner_requested: true)
  end

  it "stops before a provider side effect when another worker has taken its lease" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    replacement_token = SecureRandom.uuid
    allow(CalendarSyncs::Event).to receive(:new).and_wrap_original do |original, *args, **kwargs|
      connection.update_columns(sync_lease_token: replacement_token, sync_lease_expires_at: 1.minute.from_now)
      original.call(*args, **kwargs)
    end

    expect { described_class.call(connection:) }.not_to raise_error

    expect(provider).not_to have_received(:create_event)
    expect(connection.reload.sync_lease_token).to eq(replacement_token)
    expect(connection.calendar_event_syncs.find_by!(source: reminder).synced_at).to be_nil
  end

  it "leaves a new mapping pending when the lease changes during provider creation" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    replacement_token = SecureRandom.uuid
    allow(provider).to receive(:create_event) do |_attributes, event_id:|
      connection.update_columns(sync_lease_token: replacement_token, sync_lease_expires_at: 1.minute.from_now)
      event_id
    end

    described_class.call(connection:)

    expect(connection.calendar_event_syncs.find_by!(source: reminder).synced_at).to be_nil
    expect(connection.reload.sync_lease_token).to eq(replacement_token)
  end

  it "keeps mapping completion inside the owner boundary used by credential replacement" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    baseline_transactions = CalendarConnection.connection.open_transactions
    allow_any_instance_of(CalendarEventSync).to receive(:update!).and_wrap_original do |original, attributes|
      if attributes[:synced_at]
        expect(CalendarConnection.connection.open_transactions).to be > baseline_transactions
      end
      original.call(attributes)
    end

    described_class.call(connection:)

    expect(connection.calendar_event_syncs.find_by!(source: reminder).synced_at).to be_present
  end

  it "does not create a fallback event after losing the lease during an update" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    mapping = connection.calendar_event_syncs.find_by!(source: reminder)
    original_fingerprint = mapping.source_fingerprint
    reminder.update!(title: "Changed title")
    replacement_token = SecureRandom.uuid
    fallback_created = false
    allow(provider).to receive(:create_event) { fallback_created = true }
    allow(provider).to receive(:update_event) do
      connection.update_columns(sync_lease_token: replacement_token, sync_lease_expires_at: 1.minute.from_now)
      raise CalendarProviders::NotFoundError.new(code: "provider_event_missing")
    end

    described_class.call(connection:)

    expect(fallback_created).to be(false)
    expect(mapping.reload).to have_attributes(source_fingerprint: original_fingerprint, synced_at: be_present)
    expect(connection.reload.sync_lease_token).to eq(replacement_token)
  end

  it "keeps a mapping when the lease changes during provider deletion" do
    reminder = create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    described_class.call(connection:)
    mapping = connection.calendar_event_syncs.find_by!(source: reminder)
    connection.update!(sync_types: [])
    replacement_token = SecureRandom.uuid
    allow(provider).to receive(:delete_event) do
      connection.update_columns(sync_lease_token: replacement_token, sync_lease_expires_at: 1.minute.from_now)
    end

    described_class.call(connection:)

    expect(mapping.reload).to be_present
    expect(connection.reload.sync_lease_token).to eq(replacement_token)
  end

  it "takes the owner lock again to finish a sync" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    allow(connection).to receive(:user).and_return(user)

    expect(user).to receive(:with_lock).with("FOR NO KEY UPDATE").exactly(3).times.and_call_original

    described_class.call(connection:)
  end

  it "does not start duplicate work or resume a failed revocation" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(
      sync_types: [ "reminders" ],
      sync_status: "syncing",
      sync_lease_token: SecureRandom.uuid,
      sync_lease_expires_at: 1.minute.from_now
    )

    described_class.call(connection:)
    connection.update!(
      sync_status: "failed",
      sync_lease_token: nil,
      sync_lease_expires_at: nil,
      last_error_code: "revocation_failed"
    )
    described_class.call(connection:)

    expect(provider).not_to have_received(:create_event)
    expect(connection.reload).to have_attributes(sync_status: "failed", last_error_code: "revocation_failed")
  end

  it "recovers an expired syncing lease but leaves an active lease alone" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(
      sync_types: [ "reminders" ],
      sync_status: "syncing",
      sync_lease_token: SecureRandom.uuid,
      sync_lease_expires_at: 1.minute.from_now
    )

    described_class.call(connection:)
    expect(provider).not_to have_received(:create_event)

    connection.update_columns(sync_lease_expires_at: 1.minute.ago)
    described_class.call(connection:)

    expect(provider).to have_received(:create_event).once
    expect(connection.reload).to have_attributes(sync_status: "connected", sync_lease_token: nil, sync_lease_expires_at: nil)
  end

  it "does not add user-visible audit noise for a no-op reconciliation" do
    connection.update!(sync_types: [])

    expect { described_class.call(connection:) }
      .not_to change { AuditEvent.where(action: "calendar.sync.completed").count }
  end

  it "surfaces authorization failures without retaining provider details" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    allow(provider).to receive(:create_event).and_raise(
      CalendarProviders::AuthorizationError.new("provider token abc-secret", code: "authorization_required")
    )

    expect { described_class.call(connection:) }.not_to raise_error

    expect(connection.reload).to have_attributes(sync_status: "action_required", last_error_code: "authorization_required")
    expect(connection.attributes.to_json).not_to include("abc-secret")
  end

  it "records retryable failures before reraising for the job retry policy" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    error = CalendarProviders::TransientError.new("timeout with private detail", code: "provider_unavailable")
    allow(provider).to receive(:create_event).and_raise(error)

    expect { described_class.call(connection:) }.to raise_error(error)

    expect(connection.reload).to have_attributes(sync_status: "failed", last_error_code: "provider_unavailable")
    expect(AuditEvent.order(:created_at).last).to have_attributes(
      action: "calendar.sync.failed",
      metadata: { "result" => "provider_unavailable" }
    )
  end

  it "acquires the owner lock before the connection lock when recording a provider failure" do
    create(:reminder, user:, relationship_profile: profile)
    connection.update!(sync_types: [ "reminders" ])
    error = CalendarProviders::TransientError.new("timeout", code: "provider_unavailable")
    failure_phase = false
    failure_lock_order = []
    allow(connection).to receive(:user).and_return(user)
    allow(provider).to receive(:create_event) do
      failure_phase = true
      raise error
    end
    allow(user).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      failure_lock_order << :owner if failure_phase
      original.call(*args, &block)
    end
    allow(connection).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      failure_lock_order << :connection if failure_phase
      original.call(*args, &block)
    end

    expect { described_class.call(connection:) }.to raise_error(error)

    expect(failure_lock_order.first(3)).to eq([ :owner, :connection, :owner ])
  end

  it "allows an owner-requested retry after a permanent provider failure" do
    connection.update!(sync_status: "failed", last_error_code: "provider_rejected", sync_types: [])

    described_class.call(connection:, owner_requested: true)

    expect(connection.reload).to have_attributes(sync_status: "connected", last_error_code: nil)
  end
end
