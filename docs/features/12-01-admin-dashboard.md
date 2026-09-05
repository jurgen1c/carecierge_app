# 12.1 Admin Dashboard

**Area:** 12. Admin and Internal Tools

Internal dashboard for managing users, vendors, templates, feedback, and system health.

## Capabilities

- View users.
- View relationship template definitions.
- Manage vendor categories.
- Moderate marketplace listings.
- Review AI feedback.
- Monitor failed jobs.
- View audit logs.
- Manage feature flags.

## Possible Data Objects

- Admin user roles
- Feature flags
- Internal notes
- Vendor moderation status

## Implementation Notes

Avo or a similar admin framework could accelerate this if using Rails.

## Delivered overview (CAR-75)

`GET /admin` provides an admin-only aggregate overview. Both desktop and mobile
account navigation expose it only to administrators. Each non-prefetched visit
records `admin.dashboard.viewed` in the administrator's activity ledger before
reading aggregates. Responses use no-store and disable Turbo snapshots.

The overview shows account and feature-default counts, catalog publication
counts, persisted approval backlog and oldest waiting date, stored integration
recovery states, failed/ready/scheduled/concurrency-blocked jobs and recent
worker counts. Queue monitoring explicitly reports unavailable when storage
cannot be read. No recent worker heartbeat does not establish a running worker,
and stored integration state is not a live provider health check.

Trust guidance uses failed vault unlocks in the last 24 hours and retained
suggestion-feedback totals as signals, never an abuse verdict. Support can use
the existing account-filtered admin ledger for a reported concern and escalate
for human review; the overview does not create a moderation queue. Counts are
current database observations and can change between reads.

Relationship content, account identities, job payloads, raw errors and credentials
are not returned. Approval discovery/decisions, job retries, provider sync,
impersonation, account suspension and catalog moderation are not actions on this
page. Owners retain integration and approval controls. Feature changes retain
the existing audited maintenance workflow; catalog changes require separately
authorized maintenance. The broader capability list above remains future work
where no existing authorized surface is linked.

### Admin framework decision

Avo and RailsAdmin were considered in response to the ticket comment. Their
[custom admin tooling](https://docs.avohq.io/4.0/) and
[authorization support](https://github.com/railsadminteam/rails_admin) could help a
broader CRUD-oriented internal application. This aggregate overview reuses the
existing Devise/Pundit admin namespace, audit ledger and ViewComponents because
its privacy-safe queries and scoped recovery guidance are custom either way.
No additional admin engine or generic tenant model CRUD is installed.

### Verification

`bundle exec rspec spec/requests/admin_dashboard_spec.rb spec/queries/admin_dashboard_query_spec.rb spec/models/admin_dashboard/queue_status_spec.rb spec/components/admin_metric_section_component_spec.rb spec/system/admin_dashboard_spec.rb`
