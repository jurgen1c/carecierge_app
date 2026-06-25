---
id: feature_flags.decision_precedence
type: fact
system: feature_flags
status: current
confidence: verified
severity: critical

title: Feature flag decisions use deterministic assignment precedence

claim: >
  FeatureFlag.enabled? builds context from user, account, segment, rollout group, and
  environment inputs, then applies targeted assignments in deterministic precedence: user,
  account, segment, rollout group, environment, and global.

source_files:
  - app/models/feature_flag.rb
  - app/models/feature_flag_assignment.rb
  - app/models/feature_flags/context.rb
  - app/models/rollout_group.rb

related_files:
  - spec/models/feature_flag_spec.rb
symbols:
  - FeatureFlag
  - FeatureFlagAssignment
  - FeatureFlags::Context
  - RolloutGroup
routes: []
tags:
  - feature_flags
  - rollout

verification:
  - bundle exec rspec spec/models/feature_flag_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Feature flag decisions use deterministic assignment precedence

## Claim

`FeatureFlag.enabled?` builds context from user, account, segment, rollout group, and
environment inputs, then applies targeted assignments in deterministic precedence: user,
account, segment, rollout group, environment, and global.

## Why It Matters

Flag behavior protects staged and sensitive capabilities, so precedence changes can silently
change who receives experimental behavior.

## Evidence

- `app/models/feature_flag.rb`
- `app/models/feature_flag_assignment.rb`
- `app/models/feature_flags/context.rb`
- `app/models/rollout_group.rb`

## Verification

- `bundle exec rspec spec/models/feature_flag_spec.rb`
