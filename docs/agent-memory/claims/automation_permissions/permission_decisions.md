---
id: automation_permissions.permission_decisions
type: fact
system: automation_permissions
status: current
confidence: high
severity: critical

title: Automation permissions fail closed with owner-scoped overrides and audited changes

claim: >
  AutomationCapability declares the supported capability catalog, risk level,
  required permissions, and allowed modes. Missing settings and archived
  relationship contexts resolve to disabled. Supplied relationships are
  re-resolved through the owner's current kept scope before an override is
  selected, and permission records validate relationship ownership against
  persisted owner-scoped profile data. Kept, owner-scoped relationship
  overrides take precedence over account defaults, while foreign relationship
  contexts are rejected.
  Ask-every-time decisions require a literal boolean
  approval signal,
  and high-impact purchase and deposit capabilities cannot be allowed
  automatically. Permission writes and removals create append-only
  AutomationPermissionChange audit events in the same transaction. Permission
  writes and removals serialize on the owner before locking permission rows;
  bulk default changes acquire that owner lock once for the batch. A newly
  created relationship override records its inherited account mode as the
  previous audit state.
  Relationship deletion audits each
  override removal, and those audit rows retain relationship UUID scope after
  profile deletion; they are removed only when their owning account is deleted.

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

Carecierge evaluates automation through a closed capability catalog. An absent
setting is disabled, a relationship override only applies inside the owning
account and before its account default, and the relationship is re-read through
the owner's current kept scope so stale instances cannot retain effective
automation access. Relationship ownership validation reads the persisted
owner/profile pair so dirty association state cannot cross the tenant boundary.
Ask-every-time and every high-impact action
require a literal `true` approval signal. High-impact capabilities cannot be
saved as automatic. All supported mutations create immutable audit records
atomically, writes and removals use a consistent owner-then-permission lock
order, and bulk default updates hold the owner lock once across the complete
batch. A new relationship override records the inherited account default as
its prior audit mode. Relationship deletion records removal events before
destroying overrides. Deleting a relationship
does not erase an audit row's relationship UUID, while account deletion removes
the account's audit history without invoking row-level mutation callbacks.

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
- `db/migrate/20260806120000_create_automation_permissions.rb`
- `spec/models/automation_permission_spec.rb`
- `spec/models/automation_permission_decision_spec.rb`
- `spec/services/automation_permissions/change_spec.rb`
- `spec/services/automation_permissions/update_defaults_spec.rb`
- `spec/requests/automation_permissions_spec.rb`

## Verification

- `bundle exec rspec spec/models/automation_capability_spec.rb spec/models/automation_permission_spec.rb spec/models/automation_permission_decision_spec.rb spec/models/automation_permission_change_spec.rb spec/services/automation_permissions/change_spec.rb spec/services/automation_permissions/update_defaults_spec.rb spec/policies/automation_permission_policy_spec.rb spec/requests/automation_permissions_spec.rb spec/components/automation_permission_mode_component_spec.rb spec/components/automation_permission_override_component_spec.rb spec/components/automation_capability_row_component_spec.rb spec/components/automation_capability_inspector_component_spec.rb spec/system/automation_permissions_spec.rb`
- `bundle exec rspec`
- `bin/rubocop`
- `bin/ci`
