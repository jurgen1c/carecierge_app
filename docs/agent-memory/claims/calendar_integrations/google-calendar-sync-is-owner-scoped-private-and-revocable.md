---
id: calendar_integrations.google_calendar_sync_is_owner_scoped_private_and_revocable
type: fact
system: calendar_integrations
status: current
confidence: verified
severity: critical

title: Google Calendar sync is owner-scoped, private, and revocable

claim: >
  Each account can hold one encrypted Google Calendar connection obtained
  through a short-lived, owner-bound, single-use OAuth state and the narrow
  calendar.events.owned scope. Nothing syncs until the owner enables one or
  more supported source types. Immediate and 15-minute reconciliation reads
  only owner-scoped active sources and publishes private, transparent events
  containing a title, scheduled date or time, a constant Carecierge label, and
  recurrence when applicable, never notes, locations, confirmations, guest
  lists, or provider response bodies. Mappings and OAuth credentials are
  encrypted. Immediately before each provider create or update, the fail-closed
  access_calendar automation permission is re-evaluated for the source's
  relationship: ask-every-time permits an explicitly owner-requested run,
  relationship overrides take precedence, and periodic work requires automatic
  permission. Reminder relationships are derived from every supported attachment
  when the direct relationship is absent; ambiguous or archived attachment
  contexts are ineligible. Blocked selected records produce a visible permission-required
  failure and settings action instead of a successful sync. Provider deletion
  remains authorized as privacy cleanup under the owner lock when a
  previously synced source becomes deselected, removed, or ineligible after
  its relationship is archived. The
  connection persists its authorization locale so generated titles remain
  stable across request and background-job locales. Safe status codes and
  count-only audit evidence expose recovery;
  authorization failures require reconnect, transient failures retry with a
  bound, while durable pending mappings and deterministic owner-and-source
  provider IDs make inserts retry-idempotent even across later source changes
  or removal. Conflicting retained events are updated before being accepted,
  and a bounded deterministic replacement chain remains discoverable after a
  later reconnect when Google reports deleted-event tombstones as 404 or 410. Active
  sync state uses an expiring lease committed before provider calls, so
  duplicate work is fenced without invalidating token-refresh writes, a worker
  that loses its lease stops before another provider mutation, interrupted work
  recovers, each successful lease renewal reloads the connection before provider
  token checks, and concurrent setting changes request a follow-up while refreshed
  credentials, each provider result, and its mapping completion are serialized
  under a fresh per-source owner and connection boundary. The owner lock is
  released between sources so concurrent consent changes can commit before the
  next disclosure. Each discovered source's profile IDs are derived from its
  preloaded relationship paths, then those profiles and an eager-loaded fresh
  source are locked before permission evaluation, including the unchanged-mapping
  path, so concurrent edits, deletion, archival, and permission changes cannot
  publish stale or newly ineligible content.
  Successful mapping changes atomically increment durable pending evidence under
  the current lease token in their transaction, and completion uses a separate
  owner boundary to record and clear that evidence before connected status
  commits. Sync selections are reduced to the supported unique set and stored in
  canonical source order; duplicate or unsupported inputs cannot fail the save,
  and reordered submissions of the same set neither enqueue reconciliation nor
  emit settings activity.
  Calendar connection and sync owner boundaries use FOR NO KEY UPDATE before
  dependent-row locks so foreign-key checks do not contend with an unnecessarily
  strong owner lock.
  Failure status changes likewise acquire the owner boundary before the
  connection row, while the subsequent audit insert uses a fresh owner boundary
  before locking its target, so failure recovery cannot invert the owner-first
  lock order.
  Disconnect flushes any evidence retained by a partial failed run before
  destroying the connection.
  Token-endpoint throttling
  and outages remain transient even when their response body is not JSON. Authorization, permanent, and revocation
  failures are never scheduled as periodic retries, but a settings resync queued
  during a failing run is consumed as one owner-requested follow-up so cleanup is
  not stranded; the owner can explicitly retry a permanent sync failure after
  changing the affected selections. One-time snoozes and
  clamped month-end important-date and reminder recurrences retain Carecierge semantics even
  after an old anchor's original hundred-year window has elapsed, while unchanged runs do
  not create activity-ledger noise, and deleted provider events are recreated
  after a source change. Disconnect
  retains local credentials until Google confirms revocation, then
  nullifies historical audit targets and deletes the credentials and mappings
  while leaving already-created Google events under the owner's control. A
  failed revocation preserves the existing credential and offers only another
  disconnect attempt; UI, routes, and credential persistence all reject a
  connection flow that could overwrite that token. A persisted connection
  generation also prevents an older in-flight OAuth callback from restoring
  access after disconnect, and credentials returned by a superseded exchange
  are explicitly revoked. Each accepted callback advances that generation, and
  token exchange and savepoint-backed persistence share the owner deletion lock,
  persistence rolls back before cleanup begins, revoke-or-store cleanup finishes
  before that lock is released, and cleanup is guaranteed even when reconnect
  compensation raises. Pending
  callback revocations retain whichever live token Google returned, block later
  authorization, and replace the connect control with cleanup-specific recovery
  guidance, while a live connection whose revocation failed retains the separate
  disconnect-retry guidance.
  External authorization launches bypass Turbo so the
  provider redirect remains a top-level navigation. If immediate callback cleanup
  fails, its encrypted credentials remain in an owner-scoped durable revocation
  record retried by both a scheduled job and a recurring recovery sweep; account
  deletion must revoke those records before removing the owner. Failure to revoke
  a pending callback credential leaves an as-yet untouched live connection in its
  existing healthy state. Account deletion revokes provider access inside the
  owner-locked deletion boundary and preserves the account and credentials when
  revocation cannot be confirmed. Devise's deletion route cannot bypass that
  boundary. If a later local deletion step rolls back after successful provider
  revocation, the restored connection becomes reconnect-required and its
  generation advances before the owner lock is released. An ordinary disconnect
  applies the same uninterrupted owner-locked savepoint and compensation when
  local removal or audit work rolls back after successful provider revocation.
  Ordinary reauthorization revokes the prior credential before
  replacement and marks existing mappings pending so unchanged selected events
  are published into the newly authorized primary calendar. Failed prior
  revocation preserves it, durably blocks later authorization outside the
  rolled-back savepoint, and cleans up the new credential; a local replacement
  failure after prior revocation fences the restored connection as
  reconnect-required.
  Account exports include safe connection
  and source-reference metadata but exclude credentials, scopes, provider
  event IDs, fingerprints, internal lease and pending-evidence state, and failure codes.

source_files:
  - app/models/calendar_connection.rb
  - app/models/calendar_credential_revocation.rb
  - app/models/calendar_event_sync.rb
  - app/controllers/calendar_connections_controller.rb
  - app/controllers/users/registrations_controller.rb
  - app/services/calendar_connections/oauth_state.rb
  - app/services/calendar_connections/save_credentials.rb
  - app/services/calendar_connections/update_settings.rb
  - app/services/calendar_connections/google_oauth.rb
  - app/services/calendar_connections/disconnect.rb
  - app/services/calendar_providers/google.rb
  - app/services/calendar_providers/lease_lost_error.rb
  - app/services/calendar_syncs/run.rb
  - app/services/calendar_syncs/source_relationship.rb
  - app/services/calendar_syncs/sources.rb
  - app/services/calendar_syncs/event.rb
  - app/services/data_deletions/delete_account.rb
  - app/jobs/calendar_sync_job.rb
  - app/jobs/calendar_credential_revocation_job.rb
  - app/jobs/dispatch_calendar_credential_revocations_job.rb
  - app/jobs/dispatch_calendar_syncs_job.rb
  - app/serializers/data_exports/snapshot.rb
  - config/deploy.yml
  - db/migrate/20260903200000_create_calendar_connections.rb
  - db/migrate/20260903201000_harden_calendar_connections.rb
  - db/migrate/20260903202000_constrain_calendar_connection_error_codes.rb
  - db/migrate/20260903203000_add_calendar_sync_leases.rb
  - db/migrate/20260903204000_add_calendar_connection_generation_to_users.rb
  - db/migrate/20260903205000_add_locale_to_calendar_connections.rb
  - db/migrate/20260903206000_create_calendar_credential_revocations.rb
  - db/migrate/20260903207000_allow_partial_calendar_credential_revocations.rb
  - db/migrate/20260903208000_add_pending_audit_count_to_calendar_connections.rb

related_files:
  - app/models/audit_event.rb
  - app/models/automation_permission.rb
  - .kamal/secrets
  - app/models/user.rb
  - app/policies/calendar_connection_policy.rb
  - app/presenters/audit_event_presenter.rb
  - app/views/components/calendar_connection_component.rb
  - app/views/components/calendar_connection_component.html.erb
  - app/views/dashboard/index.html.erb
  - config/locales/daily_feed.en.yml
  - config/locales/daily_feed.es.yml
  - config/locales/en.yml
  - config/locales/es.yml
  - config/recurring.yml
  - docs/features/11-01-calendar-integration.md
  - spec/requests/calendar_connections_spec.rb
  - spec/requests/data_controls_spec.rb
  - spec/config/calendar_integration_deploy_spec.rb
  - spec/presenters/audit_event_presenter_spec.rb
  - spec/services/calendar_connections/google_oauth_spec.rb
  - spec/services/calendar_connections/disconnect_spec.rb
  - spec/services/calendar_connections/update_settings_spec.rb
  - spec/services/calendar_providers/google_spec.rb
  - spec/services/calendar_syncs/run_spec.rb
  - spec/models/calendar_credential_revocation_spec.rb
  - spec/serializers/data_exports/snapshot_spec.rb
  - spec/system/calendar_connections_spec.rb
symbols:
  - CalendarConnection
  - CalendarCredentialRevocation
  - CalendarEventSync
  - CalendarConnectionsController
  - CalendarConnections::OauthState
  - CalendarConnections::GoogleOauth
  - CalendarConnections::Disconnect
  - CalendarProviders::Google
  - CalendarSyncs::Run
  - CalendarSyncs::SourceRelationship
  - CalendarSyncs::Sources
  - CalendarSyncs::Event
  - CalendarSyncJob
  - CalendarCredentialRevocationJob
  - DispatchCalendarCredentialRevocationsJob
  - DispatchCalendarSyncsJob
routes:
  - calendar_connection
  - new_calendar_connection
  - callback_calendar_connection
  - sync_calendar_connection
tags:
  - calendar_integrations
  - google_calendar
  - oauth
  - privacy
  - owner_scope
  - revocation

verification:
  - bundle exec rspec spec/models/calendar_connection_spec.rb spec/models/calendar_credential_revocation_spec.rb spec/models/calendar_event_sync_spec.rb spec/policies/calendar_connection_policy_spec.rb spec/services/calendar_connections spec/services/calendar_providers spec/services/calendar_syncs spec/jobs/calendar_sync_job_spec.rb spec/jobs/dispatch_calendar_syncs_job_spec.rb spec/jobs/calendar_credential_revocation_job_spec.rb spec/jobs/dispatch_calendar_credential_revocations_job_spec.rb spec/components/calendar_connection_component_spec.rb spec/requests/calendar_connections_spec.rb spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/system/calendar_connections_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: f1ad1752ebd0d8221707417cb61a929042346f38
---

# Google Calendar sync is owner-scoped, private, and revocable

## Claim

An account owner explicitly connects Google Calendar and selects which
Carecierge sources may leave the application. The application keeps provider
credentials and mappings encrypted, sends a deliberately minimal event body,
rechecks the canonical relationship-aware calendar automation permission before
each provider create or update, exposes blocked selections with a direct
permission action, retains provider deletion as owner-serialized privacy cleanup,
keeps generated titles in the connection's persisted locale, and presents safe
recovery actions without retaining provider details.

## Why It Matters

Calendar access crosses Carecierge's privacy boundary. The narrow scope,
owner-only source queries, content minimization, idempotent inserts, bounded
retry classification, visible revocation semantics, and content-free audit
trail prevent the integration from becoming an implicit data-sharing or
cross-account channel.

## Evidence

- `app/models/calendar_connection.rb`
- `app/services/calendar_syncs/run.rb`
- `app/services/calendar_connections/disconnect.rb`
- `spec/requests/calendar_connections_spec.rb`

## Verification

- `bundle exec rspec spec/models/calendar_connection_spec.rb spec/models/calendar_credential_revocation_spec.rb spec/models/calendar_event_sync_spec.rb spec/policies/calendar_connection_policy_spec.rb spec/services/calendar_connections spec/services/calendar_providers spec/services/calendar_syncs spec/jobs/calendar_sync_job_spec.rb spec/jobs/dispatch_calendar_syncs_job_spec.rb spec/jobs/calendar_credential_revocation_job_spec.rb spec/jobs/dispatch_calendar_credential_revocations_job_spec.rb spec/components/calendar_connection_component_spec.rb spec/requests/calendar_connections_spec.rb spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/system/calendar_connections_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
