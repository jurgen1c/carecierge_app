---
id: approvals.owner_scoped_review_queue
type: fact
system: approvals
status: current
confidence: high
severity: critical

title: Approval queue centralizes owner decisions without external execution

claim: >
  ApprovalRequest is an owner-scoped, source-versioned envelope whose append-only
  decisions preserve user history. Synchronization uses a no-key account lock,
  adapts only pending extracted memory and blocked high-impact facts, excludes
  vault-protected memory, bounds each visit without starving obsolete work,
  derives request metadata after locking the source, refreshes edited eligible
  work, and supersedes obsolete work without inventing a user decision.
  Application locks and verifies the source version, carries
  the refreshed lock version through explicit source review, preserves the
  selected item independently of pagination, uses the owner's zone for deferral, delegates
  canonical mutation, and records content-free audit evidence. Explicit source
  reversals receive a new history envelope. Source decisions are allowlisted,
  atomic under the profile lock, and matching terminal retries are idempotent;
  mismatched retries and ineligible controls fail safely with localized feedback.
  Failed queue forms retain their selected page and mode.
  Future kinds fail closed, and high-impact memory approval never performs an
  external effect.

source_files:
  - app/models/approval_request.rb
  - app/models/approval_decision.rb
  - app/services/approval_queue/synchronize.rb
  - app/services/approval_queue/eligibility.rb
  - app/services/approval_queue/record_source_decision.rb
  - app/services/approval_decisions/apply.rb
  - app/controllers/approval_requests_controller.rb
  - app/policies/approval_request_policy.rb
  - app/presenters/approval_queue/item.rb
  - app/views/approval_requests/index.html.erb
  - app/views/components/approval_queue_item_component.rb
  - app/views/components/approval_queue_item_component.html.erb
  - db/migrate/20260828133138_create_approval_queue.rb

related_files:
  - app/controllers/extracted_memories_controller.rb
  - app/controllers/memory_records_controller.rb
  - app/models/audit_event.rb
  - app/models/extracted_memory.rb
  - app/models/memory_record.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/memory_extractions/review.rb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/approvals.en.yml
  - config/locales/approvals.es.yml
  - config/routes.rb
  - docs/features/10-03-approval-queue.md
  - spec/models/approval_request_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
  - spec/presenters/audit_event_presenter_spec.rb
  - spec/presenters/approval_queue/item_spec.rb
  - spec/services/approval_queue/synchronize_spec.rb
  - spec/services/approval_queue/record_source_decision_spec.rb
  - spec/services/approval_decisions/apply_spec.rb
  - spec/requests/approvals_spec.rb
  - spec/requests/extracted_memories_spec.rb
  - spec/requests/memory_records_spec.rb
  - spec/system/approval_queue_spec.rb
symbols:
  - ApprovalRequest
  - ApprovalDecision
  - ApprovalQueue::Synchronize
  - ApprovalQueue::Eligibility
  - ApprovalQueue::RecordSourceDecision
  - ApprovalDecisions::Apply
  - ApprovalRequestsController
  - ApprovalRequestPolicy
  - ApprovalQueue::Item
  - ApprovalQueueItemComponent
routes:
  - approvals
  - approval
tags:
  - approvals
  - owner_scope
  - audit_history
  - external_effect_guardrail
  - ai_memory_extraction
  - automation_guardrails

verification:
  - bundle exec rspec spec/models/approval_request_spec.rb spec/models/audit_event_spec.rb spec/services/approval_queue/record_source_decision_spec.rb spec/services/approval_queue/synchronize_spec.rb spec/services/approval_decisions/apply_spec.rb spec/services/memory_extractions/review_spec.rb spec/policies/approval_request_policy_spec.rb spec/requests/approvals_spec.rb spec/requests/memory_records_spec.rb spec/requests/data_controls_spec.rb spec/system/approval_queue_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# Approval queue centralizes owner decisions without external execution

## Claim

The approval queue derives review items from current owner-scoped source
objects and explains source, risk, mutation, consequence, non-effects, and
reversibility. Requests store the reviewed `subject_updated_at`, not private
source content; evidence uses allowlisted scalar metadata.

Bounded synchronization uses a no-key account lock before profile, selects only
obsolete open work, and derives request kind, risk, confidence, and source
version after locking and reloading each source. Source decisions keep discovery
and application under the profile/source lock without acquiring account and
accept only source-native decisions.
Decisions reject stale or inactive sources, normalize lock input, carry refreshed
versions into canonical review, resolve an owned selected item independently of
page shifts, retain page/mode on failure, and use owner-local deferral time.
Matching terminal source retries are no-ops; mismatched retries and ineligible
controls return safe feedback. Current adapters cover extracted memory and
high-impact facts but never external execution. Future kinds require an
allowlisted adapter, owner checks, EN/ES copy, and focused tests.

## Why It Matters

Approvals sit at the privacy and automation boundary. Keeping source truth in
its owning object, reusing canonical mutations, serializing concurrent
decisions, and failing closed for unimplemented kinds prevents a generic queue
from becoming a second private-data store or a silent external-action path.

## Evidence

- `app/models/approval_request.rb`
- `app/models/approval_decision.rb`
- `app/services/approval_queue/synchronize.rb`
- `app/services/approval_queue/eligibility.rb`
- `app/services/approval_queue/record_source_decision.rb`
- `app/services/approval_decisions/apply.rb`
- `app/services/memory_extractions/review.rb`
- `app/controllers/approval_requests_controller.rb`
- `spec/services/approval_decisions/apply_spec.rb`
- `spec/system/approval_queue_spec.rb`

## Verification

- `bundle exec rspec spec/models/approval_request_spec.rb spec/models/audit_event_spec.rb spec/services/approval_queue/record_source_decision_spec.rb spec/services/approval_queue/synchronize_spec.rb spec/services/approval_decisions/apply_spec.rb spec/services/memory_extractions/review_spec.rb spec/policies/approval_request_policy_spec.rb spec/requests/approvals_spec.rb spec/requests/memory_records_spec.rb spec/requests/data_controls_spec.rb spec/system/approval_queue_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
