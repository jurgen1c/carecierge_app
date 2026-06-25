---
id: feature_flags.disabled_fallbacks
type: rule
system: feature_flags
status: current
confidence: verified
severity: important

title: Unknown and retired feature flags resolve disabled

claim: >
  Unknown feature flags resolve disabled, and retired flags always resolve disabled even when
  a matching assignment would otherwise enable them.

source_files:
  - app/models/feature_flag.rb
  - app/models/feature_flag_assignment.rb

related_files:
  - spec/models/feature_flag_spec.rb
symbols:
  - FeatureFlag
  - FeatureFlagAssignment
routes: []
tags:
  - feature_flags
  - rollout

verification:
  - bundle exec rspec spec/models/feature_flag_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Unknown and retired feature flags resolve disabled

## Claim

Unknown feature flags resolve disabled, and retired flags always resolve disabled even when
a matching assignment would otherwise enable them.

## Why It Matters

The safe fallback for missing or cleanup-stage flags is disabled behavior, especially for
sensitive or experimental capabilities.

## Evidence

- `app/models/feature_flag.rb`
- `app/models/feature_flag_assignment.rb`

## Verification

- `bundle exec rspec spec/models/feature_flag_spec.rb`
