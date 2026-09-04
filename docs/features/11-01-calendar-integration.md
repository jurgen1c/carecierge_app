# 11.1 Calendar Integration

**Area:** 11. Integrations

Carecierge can publish selected owner-scoped dates to Google Calendar while
keeping the connection, scope, event contents, failures, and revocation under
the account owner's control.

## CAR-71 Baseline

Google Calendar is the first supported provider. The integration uses its own
OAuth client, requests offline access, and requests only the
`calendar.events.owned` scope. A signed, short-lived, owner-bound, single-use
state protects the callback. Accepting credentials advances its generation so
another callback issued concurrently becomes stale. Access and refresh tokens and provider event IDs
are encrypted with Active Record Encryption and are filtered from logs.

Nothing is selected by default. An owner can independently enable important
dates, active reminders, visible dated event plans, non-terminal bookings, and
open dated commitments. Only records owned by that account and active
relationships are eligible. Carecierge creates private, transparent events
containing the title and time or date; it never sends planning notes, guest
lists, booking confirmations, saved locations, or other source details.

Every provider create or update also passes through the canonical
`access_calendar` automation permission immediately before the call.
Relationship overrides are evaluated against each source, disabled access
fails closed, `ask_every_time` permits only an explicitly owner-requested run,
and scheduled reconciliation requires `allow_automatically`. For reminders
without a direct relationship, permission is derived from their important
date, commitment, plan, task, quote, or booking attachment. Ambiguous attachment
relationships fail closed, and archived derived relationships are excluded.
Permission changes therefore govern later disclosures in an already-running
reconciliation. Reconciliation releases the owner lock between sources so a
concurrent permission change can commit before the next disclosure. Each source
and its derived relationship context are reloaded and locked inside a fresh
owner boundary before the permission check and provider write; the check also
runs for unchanged mappings. When selected records are blocked, sync stops in a visible
permission-required state with a direct path to the calendar permission settings;
it does not report a misleading successful sync. Provider deletes remain
available as privacy cleanup when a
source is deselected, removed, or made ineligible by archiving its
relationship. Cleanup deletion holds the same owner boundary as disconnect, so
no provider deletion can begin after revocation. The settings form confirms that disabling a type deletes its
previously synchronized Google events. The locale used
when the owner authorizes the connection is persisted with it, so generated
important-date titles remain stable across request and background-job locales.

Saving choices queues reconciliation immediately. Connected, recoverable
failed, and expired in-progress connections are also reconciled every 15
minutes. An expiring lease exposes active work, prevents duplicate workers,
recovers interrupted work, fences a worker before provider calls if another
worker takes its lease, and defers settings changes into a follow-up sync.
Credential refreshes serialize with owner setting changes and revalidate lease
ownership before the provider event request. Each provider result and its mapping
completion share one per-source owner boundary, so credential replacement cannot
mark an old-calendar write as complete for the new connection. Successful mapping
changes increment a durable pending-audit count in the same transaction. Sync
completion acquires its own owner boundary and records and clears that evidence
before connected status commits, so disconnect cannot remove it first. If
provider work fails, the status transition locks the owner before the connection;
the later audit insert reacquires the owner before locking its target, avoiding
an inverse lock order with concurrent settings or deletion work. If
the owner disconnects after a partial sync failure, disconnect records and
clears any remaining publication count before removing the connection.
The sync creates, updates, and removes provider events to match enabled
Carecierge records. Pending mappings are saved before provider inserts, and
deterministic owner-and-source provider IDs make ambiguous network retries safe
even if a source changes or is removed. The stable identity also lets a later
connection reclaim and update retained events instead of duplicating or
silently accepting stale content after disconnect and reconnect. If Google
retains a tombstone for an event the owner deleted there, reconciliation probes
a bounded deterministic replacement chain that remains discoverable after a
later reconnect. Unchanged events are skipped without adding activity-ledger
noise, and an event deleted in Google is recreated on the next changed source
sync. One-time reminder snoozes and Carecierge's month-end recurrence clamping
remain intact for important dates and recurring reminders, including old anchors
whose original hundred-year window has elapsed. Authorization failures stop automatic retries and show a
reconnect action. Transient failures use bounded job retries and remain
manually retryable, including token-endpoint throttling and outages. Permanent
sync failures are not scheduled automatically, but a settings change queued
during the failing run is consumed as one owner-requested follow-up so deselected
events are still reconciled. The owner can explicitly retry after correcting any
remaining affected selection. Public status and audit records contain allowlisted codes
and counts, never provider response bodies or calendar content.

Disconnecting first asks Google to revoke the token. Local encrypted
credentials and mappings are removed only after revocation succeeds. If Google
cannot confirm revocation, the connection remains visible with an explicit
retry-disconnect state and no reconnect path that could overwrite the retained
token. Successful disconnect nullifies historical audit targets. Events already
created in Google remain there for the owner to keep or delete.

OAuth state carries a persisted connection generation. A callback that began
before a completed disconnect cannot recreate the connection afterward, and
Carecierge revokes any new credentials returned by that superseded exchange.
OAuth launches use a full-page navigation so Turbo never turns Google's redirect
into a cross-origin fetch. Credential persistence rolls back before failed
callback credentials are revoked. Revoke-or-store cleanup finishes while the
owner deletion lock is still held, and cleanup still runs if reconnect
compensation itself fails. If immediate cleanup cannot reach Google,
whichever live token Google returned is retained encrypted in an owner-scoped
revocation record; the connection UI shows cleanup in progress and does not
offer another connection. Cleanup is retried by a durable job plus the recurring
recovery sweep. Account
deletion performs the same provider revocation while holding the owner deletion
boundary; if revocation cannot be confirmed, account deletion stops and keeps
the credentials available for another attempt. A pending callback-token failure
does not change a live connection that account deletion has not yet attempted to
revoke. Devise's legacy account-delete
endpoint redirects to this guarded data-control flow. If Google revocation
succeeds but a later local deletion step rolls back, the restored connection is
marked reconnect-required and its generation advances so its revoked token is
never represented as active and an older callback cannot replace it. The
rollback and compensation use an inner savepoint while retaining the owner
lock, so no worker or callback can observe the reverted connection before the
fence commits.
An ordinary disconnect applies the same compensation if Google revocation
succeeds but a later local removal or audit step rolls back, under the same
uninterrupted owner boundary.

Reauthorization first revokes the prior credential, then replaces it and marks
existing mappings pending so unchanged selected records are published into the
newly authorized primary calendar. If prior revocation fails, its credential is
preserved, a revocation-failed state commits outside the credential savepoint to
block later authorization, and the new credential is cleaned up. If replacement persistence fails
after prior revocation, the old connection is fenced as reconnect-required before
the new credential is cleaned up. A failed revocation blocks that flow in the UI,
controller, and credential store until revocation is confirmed.

Account exports include provider, sync choices, status, timestamps, and source
mapping references. They exclude OAuth credentials, granted-scope storage,
provider event IDs, fingerprints, lease state, resync flags, pending-evidence
state, and internal failure codes.

## Configuration

Set both dedicated environment variables:

- `GOOGLE_CALENDAR_CLIENT_ID`
- `GOOGLE_CALENDAR_CLIENT_SECRET`

Register the application's absolute `callback_calendar_connection_url` as an
authorized redirect URI in the Google OAuth client. When either variable is
absent, the calendar page remains available but does not render a connect
control.

## Later Scope

Apple Calendar, Outlook, inbound birthday import, meeting detection,
relationship-briefing triggers, and automatic creation of planning tasks are
not implemented by CAR-71. They require separate provider, consent, privacy,
and reconciliation design.

## Verification

- `bundle exec rspec spec/models/calendar_connection_spec.rb spec/models/calendar_credential_revocation_spec.rb spec/models/calendar_event_sync_spec.rb spec/policies/calendar_connection_policy_spec.rb spec/services/calendar_connections spec/services/calendar_providers spec/services/calendar_syncs spec/jobs/calendar_sync_job_spec.rb spec/jobs/dispatch_calendar_syncs_job_spec.rb spec/jobs/calendar_credential_revocation_job_spec.rb spec/jobs/dispatch_calendar_credential_revocations_job_spec.rb spec/components/calendar_connection_component_spec.rb spec/requests/calendar_connections_spec.rb spec/requests/data_controls_spec.rb spec/serializers/data_exports/snapshot_spec.rb spec/system/calendar_connections_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
