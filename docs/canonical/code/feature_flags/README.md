# Feature Flags

Last updated: "2026-06-24"
Status: implemented

## Purpose

Feature flags own Carecierge staged rollout controls for sensitive or experimental capabilities, including AI, automation, integrations, marketplace behavior, and other features that need deterministic release gates.

## Behavior

- `FeatureFlag.enabled?` resolves unknown flags to disabled.
- Active flags can be enabled by default or targeted through `FeatureFlagAssignment` records.
- Targeted assignment precedence is deterministic: user, account, segment, rollout group, environment, then global.
- Retired flags always resolve disabled and remain discoverable through `FeatureFlag.retired`.
- `RolloutGroup` stores named rollout cohorts for cohort-based decisions.
- `FeatureFlagAuditEvent` stores auditable flag changes when write workflows are added.
- The admin registry at `admin/feature_flags#index` is visible only to authenticated admin users.
- English remains the default locale and Spanish remains available for user-facing feature flag copy.

## Source Files

- `app/controllers/admin/feature_flags_controller.rb`
- `app/models/feature_flag.rb`
- `app/models/feature_flag_assignment.rb`
- `app/models/feature_flag_audit_event.rb`
- `app/models/feature_flags/context.rb`
- `app/models/rollout_group.rb`
- `app/models/user.rb`
- `app/policies/feature_flag_policy.rb`
- `app/views/admin/feature_flags/index.html.erb`
- `config/locales/en.yml`
- `config/locales/es.yml`
- `config/routes.rb`

## Specs

- `spec/models/feature_flag_spec.rb`
- `spec/requests/admin_feature_flags_spec.rb`
