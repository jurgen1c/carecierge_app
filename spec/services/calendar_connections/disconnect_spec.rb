require "rails_helper"

RSpec.describe CalendarConnections::Disconnect do
  let(:connection) { create(:calendar_connection) }
  let(:provider) { instance_double(CalendarProviders::Google, revoke: true) }

  before do
    allow(CalendarProviders::Google).to receive(:new).with(connection:).and_return(provider)
  end

  it "revokes provider access, removes local credentials and mappings, and audits the outcome" do
    create(:calendar_event_sync, calendar_connection: connection)
    prior_audit = create(:audit_event, user: connection.user, actor: connection.user, target: connection, action: "calendar.settings.updated")

    expect { described_class.call(connection:, actor: connection.user) }
      .to change(CalendarConnection, :count).by(-1)
      .and change(CalendarEventSync, :count).by(-1)
      .and change { AuditEvent.where(action: "calendar.connection.revoked").count }.by(1)

    expect(prior_audit.reload).to have_attributes(target: nil, target_type: nil, target_id: nil)
    expect(connection.user.reload.calendar_connection_generation).to eq(1)
  end

  it "records pending provider-write evidence before removing the connection" do
    connection.update!(pending_audit_count: 2)

    expect { described_class.call(connection:, actor: connection.user) }
      .to change { AuditEvent.where(action: "calendar.sync.completed").count }.by(1)

    event = AuditEvent.where(action: "calendar.sync.completed").order(:created_at).last
    expect(event).to have_attributes(
      actor: nil,
      actor_kind: "system",
      source: "system",
      target: nil,
      metadata: { "count" => 2, "result" => "success" }
    )
  end

  it "keeps credentials recoverable when revocation cannot be confirmed" do
    allow(provider).to receive(:revoke).and_raise(CalendarProviders::TransientError.new(code: "provider_unavailable"))

    expect(described_class.call(connection:, actor: connection.user)).to be(false)

    expect(connection.reload).to have_attributes(sync_status: "failed", last_error_code: "revocation_failed")
    expect(connection.refresh_token).to eq("refresh-token")
    expect(AuditEvent.order(:created_at).last.action).to eq("calendar.connection.revocation_failed")
    expect(connection.user.reload.calendar_connection_generation).to eq(0)
  end

  it "clears an active sync lease when revocation cannot be confirmed" do
    connection.update!(
      sync_status: "syncing",
      sync_lease_token: SecureRandom.uuid,
      sync_lease_expires_at: 1.minute.from_now
    )
    allow(provider).to receive(:revoke).and_raise(CalendarProviders::TransientError.new(code: "provider_unavailable"))

    expect(described_class.call(connection:, actor: connection.user)).to be(false)

    expect(connection.reload).to have_attributes(
      sync_status: "failed",
      last_error_code: "revocation_failed",
      sync_lease_token: nil,
      sync_lease_expires_at: nil
    )
  end

  it "marks restored credentials reconnect-required after a local failure following revocation" do
    lock_depth = 0
    root_lock_acquisitions = 0
    allow_any_instance_of(User).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      root_lock_acquisitions += 1 if lock_depth.zero?
      original.call(*args) do
        lock_depth += 1
        block.call
      ensure
        lock_depth -= 1
      end
    end
    allow(connection).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

    expect do
      described_class.call(connection:, actor: connection.user)
    end.to raise_error(ActiveRecord::RecordNotDestroyed)

    expect(provider).to have_received(:revoke)
    expect(connection.reload).to have_attributes(
      sync_status: "action_required",
      last_error_code: "authorization_required",
      sync_lease_token: nil,
      sync_lease_expires_at: nil
    )
    expect(connection.user.reload.calendar_connection_generation).to eq(1)
    expect(root_lock_acquisitions).to eq(1)
    expect(AuditEvent.order(:created_at).last).to have_attributes(
      action: "calendar.connection.revoked",
      metadata: { "result" => "success" }
    )
  end
end
