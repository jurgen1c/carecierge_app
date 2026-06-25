---
id: feature_flags.audit_event_placeholder
type: fact
system: feature_flags
status: current
confidence: verified
severity: normal

title: Feature flag audit events store future write workflow changes

claim: >
  FeatureFlagAuditEvent stores auditable feature flag change details and is available for write
  workflows as they are added, while the current canonical admin surface documents registry
  visibility.

source_files:
  - app/models/feature_flag_audit_event.rb
  - app/controllers/admin/feature_flags_controller.rb

related_files:
  - spec/models/feature_flag_audit_event_spec.rb
  - spec/requests/admin_feature_flags_spec.rb
symbols:
  - FeatureFlagAuditEvent
  - Admin::FeatureFlagsController
routes:
  - admin_feature_flags
tags:
  - feature_flags
  - audit

verification:
  - bundle exec rspec spec/models/feature_flag_audit_event_spec.rb spec/requests/admin_feature_flags_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Feature flag audit events store future write workflow changes

## Claim

`FeatureFlagAuditEvent` stores auditable feature flag change details and is available for write
workflows as they are added, while the current canonical admin surface documents registry
visibility.

## Why It Matters

Future write behavior should preserve auditability instead of mutating flags without a record
of who changed rollout state.

## Evidence

- `app/models/feature_flag_audit_event.rb`
- `app/controllers/admin/feature_flags_controller.rb`

## Verification

- `bundle exec rspec spec/models/feature_flag_audit_event_spec.rb spec/requests/admin_feature_flags_spec.rb`
