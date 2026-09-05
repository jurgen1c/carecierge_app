require "rails_helper"

RSpec.describe "Calendar connection migration" do
  it "uses UUID ownership, database constraints, encrypted-token columns, and cascading mappings" do
    migration = Rails.root.join("db/migrate/20260903200000_create_calendar_connections.rb").read
    hardening = Rails.root.join("db/migrate/20260903201000_harden_calendar_connections.rb").read
    error_codes = Rails.root.join("db/migrate/20260903202000_constrain_calendar_connection_error_codes.rb").read
    leases = Rails.root.join("db/migrate/20260903203000_add_calendar_sync_leases.rb").read
    locale = Rails.root.join("db/migrate/20260903205000_add_locale_to_calendar_connections.rb").read
    credential_revocations = Rails.root.join("db/migrate/20260903206000_create_calendar_credential_revocations.rb").read
    partial_revocations = Rails.root.join("db/migrate/20260903207000_allow_partial_calendar_credential_revocations.rb").read
    pending_audits = Rails.root.join("db/migrate/20260903208000_add_pending_audit_count_to_calendar_connections.rb").read
    schema = Rails.root.join("db/schema.rb").read

    expect(migration).to include("create_table :calendar_connections, id: :uuid")
    expect(migration).to include("type: :uuid", "index: { unique: true }")
    expect(hardening).to include("calendar_connections_supported_sync_types", "calendar_connections_required_google_scope")
    expect(error_codes).to include("calendar_connections_supported_error_code")
    expect(migration).to include("t.datetime :synced_at\n")
    expect(migration).not_to include("t.datetime :synced_at, null: false")
    expect(pending_audits).to include("pending_audit_count", "calendar_connections_nonnegative_pending_audit_count")
    expect(leases).to include("sync_lease_token", "sync_lease_expires_at", "resync_requested")
    expect(leases).not_to include("change_column_null :calendar_event_syncs")
    expect(locale).to include("null: false, default: \"en\"", "calendar_connections_supported_locale")
    expect(hardening).to include("index_calendar_event_syncs_on_connection_and_source")
    expect(migration).to include("foreign_key: { on_delete: :cascade }")
    expect(credential_revocations).to include("create_table :calendar_credential_revocations, id: :uuid")
    expect(partial_revocations).to include("calendar_credential_revocations_have_a_token")
    expect(partial_revocations).to include(
      "SET last_error_code = 'provider_error'",
      "WHERE last_error_code = 'calendar_permission_required'"
    )
    expect(schema).to include('create_table "calendar_connections", id: :uuid')
    expect(schema).to include('create_table "calendar_event_syncs", id: :uuid')
  end
end
