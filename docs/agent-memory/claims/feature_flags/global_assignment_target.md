---
id: feature_flags.global_assignment_target
type: rule
system: feature_flags
status: current
confidence: high
severity: important

title: Global feature flag assignments must target all

claim: >
  FeatureFlagAssignment records with target_kind global must use target_value all because the
  feature flag context always resolves global targeting to all.

source_files:
  - app/models/feature_flag_assignment.rb
  - app/models/feature_flags/context.rb

related_files:
  - spec/models/feature_flag_assignment_spec.rb
  - spec/models/feature_flags/context_spec.rb
symbols:
  - FeatureFlagAssignment
  - FeatureFlags::Context
routes: []
tags:
  - feature_flags
  - rollout

verification:
  - bundle exec rspec spec/models/feature_flag_assignment_spec.rb spec/models/feature_flags/context_spec.rb
last_verified_commit: null
---

# Global feature flag assignments must target all

## Claim

`FeatureFlagAssignment` records with `target_kind` `global` must use `target_value` `all`
because the feature flag context always resolves global targeting to `all`.

## Why It Matters

Other target values would look valid but never match a feature flag context, creating dead
assignments that silently fail to affect rollout decisions.

## Evidence

- `app/models/feature_flag_assignment.rb`
- `app/models/feature_flags/context.rb`

## Verification

- `bundle exec rspec spec/models/feature_flag_assignment_spec.rb spec/models/feature_flags/context_spec.rb`
