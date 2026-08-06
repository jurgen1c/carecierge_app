# 10.2 Permission-Based Automation

**Area:** 10. Privacy, Safety, and Control

Users define what the app can do automatically and what requires approval.

## Permission Categories

- Draft messages
- Send reminders
- Access contacts
- Access calendar
- Suggest gifts
- Contact vendors
- Send invitations
- Make reservations
- Make purchases
- Pay deposits
- Analyze uploaded social content

## Example Rules

- Never purchase without approval.
- Can draft but not send messages.
- Can contact vendors only after approval.
- Can create calendar events automatically.
- Can remind me about birthdays 30, 14, and 3 days before.

## Possible Data Objects

- `AutomationPermission`
- `AutomationRule`
- `PermissionScope`

## Implementation Notes

`AutomationCapability` is the canonical catalog for capability risk levels,
required permissions, and allowed modes. Account defaults are conservative:
missing records resolve to `disabled`. A kept, owner-scoped relationship profile
may have a sparse override that takes precedence over the account default;
the decision path re-resolves supplied profiles through the owner's current
`kept` scope, archived profiles resolve to `disabled`, and foreign profiles are
rejected. Permission records validate relationship ownership from persisted
owner-scoped profile data rather than potentially dirty association state.

The supported modes are `disabled`, `ask_every_time`, and
`allow_automatically`. High-impact purchase and deposit capabilities deliberately
exclude `allow_automatically`, so an explicit approval is always required before
execution. Consumers must call `AutomationPermission.decision_for` and then
`permits_execution?` before performing a governed action. Approval is accepted
only as the literal boolean `true`; truthy strings and other untrusted values
fail closed.

Permission mutations go through `AutomationPermissions::Change` (or the bulk
default wrapper) so the permission and its append-only
`AutomationPermissionChange` audit event commit atomically. The authenticated
settings surface provides account defaults in the main ledger and independently
collapsible, mutable relationship overrides in the capability inspector.
Writes and removals serialize on the owning user before locking permission rows;
bulk default changes hold that owner lock once for the whole batch. When a
relationship override is first created, its audit event records the inherited
account mode as the previous state.
Relationship deletion records a removal event for every override before
cleanup, and audit rows retain the
relationship UUID after a profile is deleted so their scope remains
distinguishable; deleting the owning account removes its audit history with the
rest of the account data.
