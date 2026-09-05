require "rails_helper"

RSpec.describe AdminDashboard::Query do
  around { |example| Timecop.freeze(Time.zone.local(2026, 9, 5, 12)) { example.run } }

  it "counts due approvals without synchronizing or exposing their subjects" do
    create(:approval_request, created_at: 3.days.ago, risk_level: "sensitive")
    due = create(:approval_request, status: "deferred", deferred_until: 1.day.from_now)
    due.update_columns(deferred_until: 1.hour.ago, created_at: 2.days.ago)
    create(:approval_request, status: "deferred", deferred_until: 1.day.from_now)
    create(:approval_request, status: "approved", decided_at: 1.day.ago)

    expect(described_class.new.approvals).to eq(approval_waiting: 2, approval_deferred: 1, approval_sensitive: 1, approval_oldest: 3.days.ago)
  end

  it "distinguishes calendar failures, expired leases, cleanup and owner authorization" do
    create(:calendar_connection, sync_status: "failed", last_error_code: "provider_error")
    create(:calendar_connection, sync_status: "action_required", last_error_code: "invalid_grant")
    create(:calendar_connection, sync_status: "syncing", sync_lease_token: SecureRandom.uuid, sync_lease_expires_at: 1.minute.ago)
    create(:calendar_connection, sync_status: "syncing", sync_lease_token: SecureRandom.uuid, sync_lease_expires_at: 1.minute.from_now)
    expect(described_class.new.integrations).to include(calendar_failed: 1, calendar_action_required: 1, calendar_stalled: 1)
  end

  it "limits trust evidence to the last 24 hours without calling it abuse" do
    create(:audit_event, action: "privacy_vault.unlock_failed", occurred_at: 1.hour.ago)
    create(:audit_event, action: "privacy_vault.unlock_failed", occurred_at: 25.hours.ago)
    expect(described_class.new.trust).to include(vault_unlock_failures: 1)
  end
end
