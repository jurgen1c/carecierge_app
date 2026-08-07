# 10.4 Audit Log

**Area:** 10. Privacy, Safety, and Control

The app records important user and system actions in an append-only,
privacy-minimized account ledger.

## Logged Actions

- Profile updated
- AI memory extracted
- Reminder created
- Message drafted
- Vendor contacted
- Booking requested
- Purchase approved
- Automation rule used
- Sensitive record accessed
- Data exported
- Data deleted

## Possible Data Objects

- `AuditLog`
- `AuditEventType`
- `Actor`
- `AuditMetadata`

## Implementation Notes

`AuditEvent` stores the account owner, actor kind and optional user actor,
action, optional polymorphic target, occurrence time, source, and a small
allowlisted metadata object. It rejects cross-account and unsupported targets,
arbitrary metadata keys, nested payloads, and persisted updates or deletes.
Target associations use `dependent: :nullify` so deleting an audited resource
does not preserve a live reference or copy its sensitive contents.
Targeted event insertion re-resolves and locks the target until commit, so a
concurrent deletion cannot leave a dangling polymorphic identifier.
Privacy-vault events deliberately target the owning relationship profile rather
than the encrypted vault item, preserving a useful, privacy-safe reference when
the encrypted item is restored and deleted.

Relationship profile and reminder create/update/lifecycle mutations commit with
their generic audit event through `AuditEvents::Track`. Existing specialized
`AutomationPermissionChange` and `VaultAccessEvent` evidence remains in place:
automation changes also write the generic event in the same owner-locked
transaction, vault mutations write both event types transactionally, and
unlock/lock/view access events keep their intentional best-effort behavior.
Successful profile and reminder submissions that do not change persisted or
autosaved state after normalization do not create false update evidence.
Existing single-reminder and active-reminder calendar exports create
`data_export.requested` evidence after successful serialization. The event
records only the export kind plus either the reminder or account target, never
calendar contents. Both export links opt out of Turbo prefetching, and requests
identified as Turbo prefetches do not create export evidence.

Authenticated account owners can view only `current_user.audit_events` at
`audit_events#index`. Admins have a separate Pundit-authorized cross-account
ledger at `admin/audit_events#index`. Both views are paginated, filter only on
allowlisted fields, and use localized English and Spanish action labels without
rendering event metadata or protected content. The account timeline applies
date filters, date grouping, and displayed times in the account's saved
notification time zone, falling back to the application time zone when no
preference exists. ISO date filters outside years 1 through 9999 fail closed
before reaching PostgreSQL. Non-scalar filter shapes such as arrays and hashes
also fail closed instead of silently broadening the account or admin ledger.

The action catalog includes approval, AI, automation, and deletion-request event
types for future callers, but this feature does not add those currently
nonexistent product workflows.
