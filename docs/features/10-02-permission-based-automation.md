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

This should be built before any real automation that touches external systems.
