---
id: audit_events.admin_dashboard_exposes_audited_aggregates_without_owner_action_authority
type: fact
system: audit_events
status: current
confidence: verified
severity: critical

title: Admin dashboard exposes audited aggregates without owner action authority

claim: >
  The admin overview authorizes User.admin? through Pundit before reading
  cross-account SQL counts and minimum dates. It records admin.dashboard.viewed
  in the administrator's own append-only audit ledger with support source and
  no target or metadata; audit failure prevents aggregate disclosure. Turbo
  prefetch receives no content and creates no event. HTTP storage and Turbo
  snapshots are disabled. Accounts, feature defaults, catalog visibility,
  persisted approval backlog, integration recovery, queue observations and
  trust signals expose no tenant identities, relationship contents, job
  arguments, errors or credentials. Queue storage absence or database failure
  is explicitly unavailable; recent workers means a heartbeat within five
  minutes, and stored integration state does not assert live provider health.
  Approval discovery and decisions, retries, provider calls, impersonation,
  suspension and moderation mutations are absent. Scoped navigation uses the
  existing admin ledger and feature flag policies; recovery guidance preserves
  owner consent and human review.

source_files:
  - app/controllers/admin/dashboard_controller.rb
  - app/policies/admin_dashboard_policy.rb
  - app/queries/admin_dashboard/query.rb
  - app/models/admin_dashboard/queue_status.rb
  - app/models/audit_event.rb
  - app/views/admin/dashboard/show.html.erb
  - app/views/components/admin_metric_section_component.rb
  - app/views/components/admin_metric_section_component.html.erb
  - config/routes.rb
  - config/locales/admin_dashboard.en.yml
  - config/locales/admin_dashboard.es.yml
related_files:
  - app/views/dashboard/index.html.erb
  - docs/features/12-01-admin-dashboard.md
  - spec/requests/admin_dashboard_spec.rb
  - spec/queries/admin_dashboard_query_spec.rb
  - spec/models/admin_dashboard/queue_status_spec.rb
  - spec/components/admin_metric_section_component_spec.rb
  - spec/system/admin_dashboard_spec.rb
symbols:
  - Admin::DashboardController
  - AdminDashboardPolicy
  - AdminDashboard::Query
  - AdminDashboard::QueueStatus
routes:
  - GET /admin
tags:
  - audit_events
  - admin
  - privacy
  - operations
verification:
  - bundle exec rspec spec/requests/admin_dashboard_spec.rb spec/queries/admin_dashboard_query_spec.rb spec/models/admin_dashboard/queue_status_spec.rb spec/components/admin_metric_section_component_spec.rb spec/system/admin_dashboard_spec.rb
last_verified_commit: 98db0839f6484c86b8b119c42dbfc9c9d72addd8
---

# Admin dashboard exposes audited aggregates without owner action authority

## Why It Matters

Operational visibility must not quietly grant support the owner's approval or
privacy authority. Aggregates and explicit unavailable states keep this boundary
reviewable while preserving actionable investigation guidance.

## Verification

Run the focused request, query, queue, component and system specs listed above.
