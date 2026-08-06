# CAR-68: Permission-based automation rules

## Ticket

- Jira: CAR-68 — Define permission-based automation rules
- Source: `docs/features/10-02-permission-based-automation.md`

## Confirmed acceptance criteria

- The capability catalog declares each automation's risk level and required permissions.
- Account owners can set each capability to Disabled, Ask every time, or Allow automatically.
- Relationship-specific overrides can replace the account default for one owned relationship and can be edited or removed independently.
- High-impact capabilities never allow automatic execution; an explicit approval is required for each execution.
- Permission mutations write append-only audit records in the same transaction.
- Missing settings fail closed to Disabled, and unknown capabilities are rejected.
- All routes are authenticated, owner-scoped, and localized in English and Spanish.

## Confirmed design direction

- Reuse the existing notification-settings ledger vocabulary: white and stone surfaces, moss actions, amber only for approval-required states, fixed product typography, and familiar controls.
- Keep all capability defaults visible in one grouped ledger.
- Use a contextual right rail on larger screens and a stacked inspector on smaller screens.
- The inspector explains the selected capability but does not duplicate its account-level permission control.
- Each relationship override owns its own native, collapsible editor with update and remove actions.
- Generated mocks are structural references only; the shipped surface uses semantic Rails ERB, ViewComponent, and CSS classes with no raster UI assets.

## Implementation boundaries

- `AutomationCapability` is the code-owned catalog and risk contract.
- `AutomationPermission` stores sparse account defaults and relationship overrides; no record means Disabled.
- `AutomationPermissionDecision` is the fail-closed execution contract. Ask-every-time and high-impact decisions require explicit approval.
- Application services own atomic permission and audit-event writes; controllers remain HTTP and authorization adapters.
- Pundit and owner-scoped relationship loading enforce account isolation.
- This ticket does not implement external contacts, calendar, vendor, reservation, purchase, payment, or social-analysis integrations.

## Repository memory context

- Systems: `authentication`, `relationship_profiles`, `reminders`
- Claims: `authentication.account_access_boundary`, `relationship_profiles.profile_crud_owner_scope`, `reminders.notification_preferences`
- New durable system target: `automation_permissions`
- Required verification: focused RSpec, request/system coverage, `bin/rubocop`, `bin/memory validate`, `bin/memory compile`, `bin/memory doctor`, `bin/memory coverage --git-diff`, `bin/memory audit --git-diff`, and `bin/ci`

## Risks

- Cross-account relationship IDs entering override mutations.
- High-impact modes bypassing the approval cap through forged params or direct model writes.
- Partial permission writes without matching audit events.
- Unknown capability keys silently becoming enabled.
- Dense desktop controls becoming inaccessible or unusable on touch-sized screens.
- Duplicate account and relationship controls creating conflicting sources of truth.

## Review record

- Codex pass 1 reproduced and drove fixes for explicit Disabled relationship
  overrides, relationship-scope retention in audit rows, and account deletion
  with immutable audit history.
- Codex pass 2 reproduced and drove fixes for literal-boolean approval checks,
  audited override cleanup during relationship deletion, serialized first-time
  writes, capability-namespaced form controls, and scope-specific accessible
  permission-group names.
- Codex pass 3 found one remaining P2: override removal locks the permission
  before its audit insert can lock the owner, while writes lock the owner first.
  A follow-up review also identified stale in-memory relationship archive state
  in permission decisions. Both findings were reproduced with regression tests
  and fixed by re-resolving the current kept relationship and using a consistent
  owner-then-permission lock order.
