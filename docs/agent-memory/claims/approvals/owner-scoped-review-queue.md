---
id: approvals.owner_scoped_review_queue
type: fact
system: approvals
status: current
confidence: high
severity: critical

title: Approval queue centralizes owner decisions without external execution

claim: >
  ApprovalRequest is an owner-scoped, source-versioned envelope with append-only
  history. Synchronization bounds candidates, locks preloaded profiles in UUID order,
  preserves those associations across source reloads, batch-loads vault state,
  excludes protected memory, and reconciles missing, stale, or temporarily
  ineligible work. Decisions use compatible no-key owner locks, verify source
  versions, normalize due deferrals before accepted refreshes, bind terminal
  source versions, mask mutable or vaulted associated content, preserve workflow
  context, use owner-local times, delegate canonical mutation, and record
  content-free evidence. Source decisions are allowlisted and idempotent only for
  matching normalized corrections; malformed, mismatched, or ineligible state fails closed.
  Future kinds fail closed, and high-impact approval never has an external effect.
  Concierge reads and decisions reuse Synchronize and Apply for the two supported
  memory-review kinds. Approval/rejection/correction previews bind both request and
  source content, including same-timestamp edits; higher-impact effects are disclosed.
  Deferral and dismissal preserve the source. Corrected proposal receipts include
  reviewed text and the canonical memory, while protected and professional sources
  remain outside this conversational queue.

source_files:
  - app/services/concierge/operations/approvals.rb
  - app/services/concierge/approval_sources.rb
  - app/services/concierge/record_version.rb
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
  - spec/services/concierge/approvals_spec.rb
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
  - spec/models/extracted_memory_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
  - spec/presenters/audit_event_presenter_spec.rb
  - spec/presenters/approval_queue/item_spec.rb
  - spec/components/approval_queue_item_component_spec.rb
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
  - bundle exec rspec spec/services/concierge/approvals_spec.rb spec/services/approval_decisions spec/services/approval_queue spec/requests/approvals_spec.rb
  - bundle exec rspec spec/models/approval_request_spec.rb spec/models/extracted_memory_spec.rb spec/models/audit_event_spec.rb spec/services/approval_queue/record_source_decision_spec.rb spec/services/approval_queue/synchronize_spec.rb spec/services/approval_decisions/apply_spec.rb spec/services/memory_extractions/review_spec.rb spec/policies/approval_request_policy_spec.rb spec/presenters/approval_queue/item_spec.rb spec/components/approval_queue_item_component_spec.rb spec/requests/approvals_spec.rb spec/requests/memory_records_spec.rb spec/requests/data_controls_spec.rb spec/system/approval_queue_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: cc0ce9edfa8a02156d651f817eea75d9f8ec4a7f
---

# Approval queue centralizes owner decisions without external execution

## Claim

Queue items derive from owner-scoped sources and explain source, risk,
consequence, non-effects, and reversibility. Requests store versions rather than
private content; evidence is allowlisted and scalar.

Synchronization takes a no-key account lock, preloads and UUID-locks profiles,
reattaches them after source reloads, and derives metadata under source locks.
Missing sources are removed. Superseded work may re-enter after temporary
ineligibility; rejected and dismissed snapshots require a source change.

Decisions take a compatible no-key account lock before profile/source locks,
verify versions, return due deferrals before accepted refreshes, refresh
confidence and risk, and bind terminal versions. Completed history masks live
or vaulted content and recap labels. Both adapters preserve canonical mutation,
off-page and failed-form context, selected deferred outcomes, owner-local times,
normalized retries, safe retries, and the no-external-execution boundary.

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

- `bundle exec rspec spec/models/approval_request_spec.rb spec/models/extracted_memory_spec.rb spec/models/audit_event_spec.rb spec/services/approval_queue/record_source_decision_spec.rb spec/services/approval_queue/synchronize_spec.rb spec/services/approval_decisions/apply_spec.rb spec/services/memory_extractions/review_spec.rb spec/policies/approval_request_policy_spec.rb spec/presenters/approval_queue/item_spec.rb spec/components/approval_queue_item_component_spec.rb spec/requests/approvals_spec.rb spec/requests/memory_records_spec.rb spec/requests/data_controls_spec.rb spec/system/approval_queue_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
