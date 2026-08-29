---
id: audit_events.account_activity_ledger
type: fact
system: audit_events
status: current
confidence: high
severity: critical

title: Audit events provide privacy-minimized account and admin history

claim: >
  AuditEvent is an append-only, account-owned ledger of action, actor kind,
  source, occurrence time, optional authorized actor and owner-matched target,
  and allowlisted scalar metadata. It rejects unsupported or cross-account
  targets, arbitrary keys, nested payloads, and persisted mutation. Target
  deletion nullifies the reference; insertion re-resolves and locks the target
  so concurrent deletion cannot leave a dangling ID. Profile and reminder
  mutations record through AuditEvents::Track. Automation permissions add the
  generic event beside specialized evidence in the same owner lock, while vault
  events preserve existing transactional and best-effort semantics. Approval
  decisions target owner-matched requests with request-kind and result metadata
  only, and request deletion nullifies that target while preserving evidence. Gift
  recommendation generation and lifecycle actions, plus event-plan suggestion
  generation, add result/count-only evidence without titles, rationales,
  budgets, plan details, or source contents. Calendar
  exports emit privacy-minimized evidence after serialization; Turbo prefetches
  do not. Account and profile data exports add scope/format-only evidence after
  successful serialization, and permanent deletion adds request-kind-only
  evidence before owned records are destroyed. The account route scopes from
  current_user.audit_events; a separate
  Pundit-protected admin route exposes a paginated cross-account ledger. Account
  history uses the saved notification time zone. Localized views never render
  raw metadata or sensitive content, and vault events target the owning
  relationship. Normalized no-op profile and reminder submissions emit no
  update event. Out-of-range dates and non-scalar filter shapes fail closed.

source_files:
  - app/models/audit_event.rb
  - app/services/audit_events/track.rb
  - app/queries/audit_events/query.rb
  - app/policies/audit_event_policy.rb
  - app/controllers/audit_events_controller.rb
  - app/controllers/admin/audit_events_controller.rb
  - app/presenters/audit_event_presenter.rb
  - app/views/audit_events/index.html.erb
  - app/views/admin/audit_events/index.html.erb
  - db/migrate/20260807045425_create_audit_events.rb

related_files:
  - app/views/audit_events/_filters.html.erb
  - app/views/audit_events/_pagination.html.erb
  - app/views/components/audit_event_marker_component.rb
  - docs/features/10-04-audit-log.md
  - spec/models/audit_event_spec.rb
  - spec/requests/audit_events_spec.rb
  - spec/requests/admin_audit_events_spec.rb
  - spec/requests/audit_event_integrations_spec.rb
  - app/services/gift_recommendations/generate.rb
  - app/services/gift_recommendations/apply_action.rb
  - spec/services/gift_recommendations/generate_spec.rb
  - spec/requests/gift_recommendations_spec.rb
  - app/services/event_plans/suggest.rb
  - spec/services/event_plans/suggest_spec.rb
  - app/models/approval_request.rb
  - app/services/approval_decisions/apply.rb
  - spec/services/approval_decisions/apply_spec.rb

symbols:
  - AuditEvent
  - AuditEvents::Track
  - AuditEvents::Query
  - AuditEventPolicy
  - AuditEventPresenter
  - AuditEventsController
  - Admin::AuditEventsController
  - AuditEventMarkerComponent

routes:
  - audit_events
  - admin_audit_events

tags:
  - audit_events
  - privacy_minimized_ledger
  - append_only_account_history
  - authorized_audit_admin

verification:
  - bundle exec rspec spec/models/audit_event_spec.rb spec/services/audit_events/track_spec.rb spec/queries/audit_events/query_spec.rb spec/policies/audit_event_policy_spec.rb spec/requests/audit_events_spec.rb spec/requests/admin_audit_events_spec.rb spec/requests/audit_event_integrations_spec.rb spec/models/vault_access_event_spec.rb spec/services/automation_permissions/change_spec.rb
  - bundle exec rspec
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Audit events provide privacy-minimized account and admin history

## Claim

Carecierge records important actions without copying sensitive relationship
content. Owners receive their own chronological timeline; admins use a separate,
authorized cross-account ledger. Pagination and allowlisted filters fail closed
for forged, non-scalar, malformed, or out-of-range values.

Existing profile, reminder, automation-permission, privacy-vault, gift
recommendation, event-plan suggestion, approval decision, and calendar export flows emit privacy-minimized evidence
without weakening their transaction semantics. Calendar links disable Turbo prefetch, and server-identified
prefetches create no evidence. Normalized no-op saves create no update event.

## Why It Matters

Audit history is itself sensitive. Account scoping, admin authorization,
allowlisted metadata, nullified deleted targets, and content-safe presentation
provide accountability without creating a second store of private notes,
credentials, payloads, or protected-vault contents.
Targeted event insertion holds a lock on a freshly re-resolved target until the
insert commits, so a concurrent delete either nullifies the committed reference
or causes the insert to fail without retaining a stale polymorphic identifier.

Account-local dates remain meaningful at UTC day boundaries because owner
history filtering, grouping, and time labels all use the saved notification time
zone. Privacy-vault audit history remains useful after encrypted-item deletion
because its generic target is the owning relationship profile.

## Evidence

- `app/models/audit_event.rb`
- `app/services/audit_events/track.rb`
- `app/queries/audit_events/query.rb`
- `app/controllers/audit_events_controller.rb`
- `app/controllers/admin/audit_events_controller.rb`
- `spec/requests/audit_event_integrations_spec.rb`

## Verification

- `bundle exec rspec spec/models/audit_event_spec.rb spec/services/audit_events/track_spec.rb spec/queries/audit_events/query_spec.rb spec/policies/audit_event_policy_spec.rb spec/requests/audit_events_spec.rb spec/requests/admin_audit_events_spec.rb spec/requests/audit_event_integrations_spec.rb spec/models/vault_access_event_spec.rb spec/services/automation_permissions/change_spec.rb`
- `bundle exec rspec`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
