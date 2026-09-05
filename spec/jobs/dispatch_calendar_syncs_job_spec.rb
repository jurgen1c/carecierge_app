require "rails_helper"

RSpec.describe DispatchCalendarSyncsJob, type: :job do
  it "queues recoverable connections and leaves authorization failures for the owner" do
    connected = create(:calendar_connection, sync_status: "connected")
    failed = create(:calendar_connection, sync_status: "failed", last_error_code: "provider_unavailable")
    expired = create(
      :calendar_connection,
      sync_status: "syncing",
      sync_lease_token: SecureRandom.uuid,
      sync_lease_expires_at: 1.minute.ago
    )
    create(
      :calendar_connection,
      sync_status: "syncing",
      sync_lease_token: SecureRandom.uuid,
      sync_lease_expires_at: 1.minute.from_now
    )
    create(:calendar_connection, sync_status: "action_required", last_error_code: "authorization_required")
    create(:calendar_connection, sync_status: "failed", last_error_code: "provider_rejected")
    create(:calendar_connection, sync_status: "failed", last_error_code: "revocation_failed")

    expect { described_class.perform_now }
      .to have_enqueued_job(CalendarSyncJob).with(connected)
      .and have_enqueued_job(CalendarSyncJob).with(failed)
      .and have_enqueued_job(CalendarSyncJob).with(expired)
      .and have_enqueued_job(CalendarSyncJob).exactly(3).times
  end
end
