# 6.5 Backup Plan Generator

**Area:** 6. Planning Workflows

The app creates comparable contingency options from an active event plan and
lets the owner explicitly promote one recovery path.

## Capabilities

- Generate up to three structured options for weather, vendor, gift-delay,
  restaurant, transportation, and illness/cancellation scenarios.
- Compare effort, timing, estimated cost, relationship fit, preserved
  constraints, planned changes, source evidence, and task impact. Before
  promotion, each option shows every task it will add, every current task it
  will retire, and the exact active reminders attached to those retiring tasks.
- Preserve public plan and relationship constraints by default. Private notes
  require an identifiable per-request choice; protected sources additionally
  require suggestion approval and an active Privacy Vault lease.
- Keep generation review-only. No option changes the plan until the owner
  explicitly promotes it.
- Preserve completed work during promotion. Only named current incomplete tasks
  may be superseded; their active reminders are retired and detached without
  deleting reminder history.
- Add promoted recovery steps as editable, source-backed AI-origin plan tasks.
- Reject stale generation and promotion when the plan or authorized source
  context changes. Promotion revalidates the stored context fingerprint and a
  fresh Privacy Vault lease when protected context was used. Fingerprints are
  rebuilt under the option's generation locale so changing the interface
  language alone does not invalidate an option. Each option also keeps an
  encrypted snapshot of the active reminders shown during review and rejects
  promotion if that set changed. Sensitive revalidation records
  metadata-only sensitive-access evidence for the revalidation read even when
  changed context rejects the promotion without changing the active plan.

## Possible Data Objects

- `BackupPlan`
- `BackupOption`
- promoted `PlanTask` records

## Implementation Notes

`BackupPlans::Generate` uses the event-plan context builder and a non-stored
strict structured provider response. It persists encrypted `BackupPlan` and
`BackupOption` records while leaving the active plan unchanged.

`BackupPlans::Promote` locks the owner, active relationship, event plan, backup
plan, and chosen option; verifies the event-plan generation fence; then applies
the fully displayed task and reminder changes transactionally. Promotion is idempotent and never
sends, schedules, contacts, books, or purchases.

After promotion, the chosen option is identified in the workspace and retains
the reviewed task and reminder impact as historical evidence; alternatives are
marked as not applied.

Backup records participate in owner exports. Selective AI deletion removes the
generated records and promoted AI tasks while restoring any superseded authored
or template tasks. Rescheduling keeps untouched superseded template deadlines
aligned so later restoration does not revive an obsolete date; detached
reminder history remains preserved. Ordinary
exports retain sensitive-source provenance but omit its plaintext content and
all internal generation fences, including the context fingerprint;
reauthenticated sensitive exports can include that content. The workspace is
localized in English and Spanish and uses calm recovery copy so a failed detail
feels manageable rather than blameworthy.
