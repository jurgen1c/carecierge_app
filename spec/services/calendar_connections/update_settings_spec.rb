require "rails_helper"

RSpec.describe CalendarConnections::UpdateSettings do
  it "records changed choices and queues reconciliation" do
    connection = create(:calendar_connection, sync_types: [])

    expect do
      described_class.call(connection:, sync_types: [ "reminders" ], actor: connection.user)
    end.to change { AuditEvent.where(action: "calendar.settings.updated").count }.by(1)
      .and have_enqueued_job(CalendarSyncJob).with(connection, owner_requested: true)

    expect(connection.reload.sync_types).to eq([ "reminders" ])
  end

  it "does not create a misleading settings audit when choices are unchanged" do
    connection = create(:calendar_connection, sync_types: [ "reminders" ])

    expect do
      described_class.call(connection:, sync_types: [ "reminders" ], actor: connection.user)
    end.not_to change { AuditEvent.where(action: "calendar.settings.updated").count }
  end

  it "defers reconciliation when another sync owns an active lease" do
    connection = create(
      :calendar_connection,
      sync_types: [],
      sync_status: "syncing",
      sync_lease_token: SecureRandom.uuid,
      sync_lease_expires_at: 1.minute.from_now
    )

    expect do
      described_class.call(connection:, sync_types: [ "reminders" ], actor: connection.user)
    end.not_to have_enqueued_job(CalendarSyncJob)

    expect(connection.reload).to have_attributes(sync_types: [ "reminders" ], resync_requested: true)
  end

  it "locks the owner before the connection" do
    connection = create(:calendar_connection, sync_types: [])
    user = connection.user

    expect(user).to receive(:with_lock).ordered.and_call_original
    expect(connection).to receive(:with_lock).ordered.and_call_original

    described_class.call(connection:, sync_types: [ "reminders" ], actor: user)
  end
end
