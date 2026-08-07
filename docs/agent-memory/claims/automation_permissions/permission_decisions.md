---
id: automation_permissions.permission_decisions
type: fact
system: automation_permissions
status: current
confidence: high
severity: critical

title: Automation permissions fail closed with owner-scoped overrides and audited changes

claim: >
  AutomationCapability owns the supported catalog, risk levels, required
  permissions, and allowed modes. Missing and archived relationship contexts
  fail closed. Relationships are re-resolved through the owner's kept scope,
  and permission records validate persisted ownership. Kept overrides precede
  account defaults; foreign and archived overrides cannot be edited or shown
  through settings.
  Ask-every-time requires literal boolean approval, and high-impact purchase and
  deposit capabilities cannot run automatically. Writes and removals create
  append-only audits atomically with owner-first locking; bulk defaults lock the
  owner once, and new overrides audit their inherited mode. Relationship
  deletion audits removals while retaining relationship UUID scope. Capability
  selection keeps Turbo restoration and rendered-location state aligned for
  browser Back navigation.

source_files:
  - app/models/automation_capability.rb
  - app/models/automation_permission.rb
  - app/models/automation_permission_decision.rb
  - app/models/automation_permission_change.rb
  - app/services/automation_permissions/change.rb
  - app/services/automation_permissions/update_defaults.rb

related_files:
  - app/controllers/automation_permissions_controller.rb
  - app/controllers/automation_permission_overrides_controller.rb
  - app/javascript/controllers/automation_permissions_controller.js
  - app/policies/automation_permission_policy.rb
  - app/views/automation_permissions/edit.html.erb
  - app/views/components/automation_capability_inspector_component.html.erb
  - app/views/components/automation_capability_row_component.html.erb
  - app/views/components/automation_permission_mode_component.html.erb
  - app/views/components/automation_permission_override_component.html.erb
  - db/migrate/20260806120000_create_automation_permissions.rb
  - docs/features/10-02-permission-based-automation.md
  - spec/models/automation_permission_spec.rb
  - spec/models/automation_permission_decision_spec.rb
  - spec/services/automation_permissions/change_spec.rb
  - spec/services/automation_permissions/update_defaults_spec.rb
  - spec/requests/automation_permissions_spec.rb
  - spec/system/automation_permissions_spec.rb

symbols:
  - AutomationCapability
  - AutomationPermission
  - AutomationPermissionDecision
  - AutomationPermissionChange
  - AutomationPermissions::Change
  - AutomationPermissions::UpdateDefaults
  - AutomationPermissionsController
  - AutomationPermissionOverridesController

routes:
  - edit_automation_permissions
  - automation_permissions
  - automation_permission_overrides
  - automation_permission_override

tags:
  - automation_permissions
  - approval

verification:
  - bundle exec rspec spec/models/automation_capability_spec.rb spec/models/automation_permission_spec.rb spec/models/automation_permission_decision_spec.rb spec/models/automation_permission_change_spec.rb spec/services/automation_permissions/change_spec.rb spec/services/automation_permissions/update_defaults_spec.rb spec/policies/automation_permission_policy_spec.rb spec/requests/automation_permissions_spec.rb spec/components/automation_permission_mode_component_spec.rb spec/components/automation_permission_override_component_spec.rb spec/components/automation_capability_row_component_spec.rb spec/components/automation_capability_inspector_component_spec.rb spec/system/automation_permissions_spec.rb
  - bundle exec rspec
  - bin/rubocop
  - bin/ci

last_verified_commit: null
---

# Automation permissions fail closed with owner-scoped overrides and audited changes

## Claim

Carecierge evaluates a closed automation catalog and defaults missing settings
to disabled. Owner-kept relationship overrides precede account defaults;
persisted ownership validation rejects cross-tenant state, while archived
overrides are ineffective, hidden, and immutable through settings endpoints.
Ask-every-time and every high-impact action require literal `true` approval,
and high-impact modes cannot be automatic. Mutations audit atomically with
owner-first locking, one owner lock per default batch, and inherited prior modes
for new overrides. Capability selection keeps Turbo restoration state aligned
for browser Back navigation. Relationship deletion audits override removal and
retains the relationship UUID; account deletion removes its audit history.

## Why It Matters

Automation can read private relationship context or cause external and financial
effects. A single fail-closed decision path, owner boundary, approval cap, and
transactional audit trail prevent callers from inventing weaker permission
semantics or leaving untracked changes.

## Evidence

- `app/models/automation_capability.rb`
- `app/models/automation_permission.rb`
- `app/models/automation_permission_decision.rb`
- `app/models/automation_permission_change.rb`
- `app/services/automation_permissions/change.rb`
- `app/controllers/automation_permissions_controller.rb`
- `app/controllers/automation_permission_overrides_controller.rb`
- `app/javascript/controllers/automation_permissions_controller.js`
- `db/migrate/20260806120000_create_automation_permissions.rb`
- `spec/models/automation_permission_spec.rb`
- `spec/models/automation_permission_decision_spec.rb`
- `spec/services/automation_permissions/change_spec.rb`
- `spec/services/automation_permissions/update_defaults_spec.rb`
- `spec/requests/automation_permissions_spec.rb`
- `spec/system/automation_permissions_spec.rb`

## Verification

- `bundle exec rspec spec/models/automation_capability_spec.rb spec/models/automation_permission_spec.rb spec/models/automation_permission_decision_spec.rb spec/models/automation_permission_change_spec.rb spec/services/automation_permissions/change_spec.rb spec/services/automation_permissions/update_defaults_spec.rb spec/policies/automation_permission_policy_spec.rb spec/requests/automation_permissions_spec.rb spec/components/automation_permission_mode_component_spec.rb spec/components/automation_permission_override_component_spec.rb spec/components/automation_capability_row_component_spec.rb spec/components/automation_capability_inspector_component_spec.rb spec/system/automation_permissions_spec.rb`
- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
