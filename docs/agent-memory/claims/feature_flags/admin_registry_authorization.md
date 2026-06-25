---
id: feature_flags.admin_registry_authorization
type: constraint
system: feature_flags
status: current
confidence: verified
severity: critical

title: Feature flag registry is admin-only

claim: >
  The admin feature flag registry at admin/feature_flags#index is visible only to authenticated
  admin users through Devise authentication and FeatureFlagPolicy authorization.

source_files:
  - app/controllers/admin/feature_flags_controller.rb
  - app/models/user.rb
  - app/policies/feature_flag_policy.rb
  - app/views/admin/feature_flags/index.html.erb
  - config/routes.rb

related_files:
  - spec/requests/admin_feature_flags_spec.rb
symbols:
  - Admin::FeatureFlagsController
  - FeatureFlagPolicy
  - User
routes:
  - admin_feature_flags
tags:
  - feature_flags
  - authentication
  - authorization

verification:
  - bundle exec rspec spec/requests/admin_feature_flags_spec.rb
last_verified_commit: 59c16d37d66419852ab109e5f68ef29f0a746e53
---

# Feature flag registry is admin-only

## Claim

The admin feature flag registry at `admin/feature_flags#index` is visible only to authenticated
admin users through Devise authentication and `FeatureFlagPolicy` authorization.

## Why It Matters

Feature flags control staged access to sensitive capabilities, so registry visibility must not
leak to unauthenticated or non-admin users.

## Evidence

- `app/controllers/admin/feature_flags_controller.rb`
- `app/models/user.rb`
- `app/policies/feature_flag_policy.rb`
- `app/views/admin/feature_flags/index.html.erb`
- `config/routes.rb`

## Verification

- `bundle exec rspec spec/requests/admin_feature_flags_spec.rb`
