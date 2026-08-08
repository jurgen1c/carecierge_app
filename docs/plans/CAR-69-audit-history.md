# CAR-69: Audit history for important actions

## Ticket

- Jira: CAR-69 — Record audit logs for important actions
- Source: `docs/features/10-04-audit-log.md`

## Confirmed acceptance criteria

- Immutable audit events record the owning account, actor kind and optional user actor, action, optional target, occurrence time, source, and allowlisted metadata.
- Existing relationship-profile (including onboarding), reminder, automation-permission, and privacy-vault workflows create audit events without weakening their current transaction and failure semantics.
- Existing single-reminder and active-reminder calendar exports record privacy-minimized export-request events; the audit catalog also supports future approval, AI, automation, and deletion-request events without implementing nonexistent product workflows in this ticket.
- Account owners can view only their own meaningful history. Admins can view a separate cross-account ledger; non-admins cannot access it.
- Deleted target references become unavailable while the event retains only minimal action evidence; privacy-vault events target the durable owning relationship rather than the encrypted item.
- Audit rows and rendered history never include protected contents, reminder notes, credentials, tokens, request payloads, or other unnecessary sensitive values.
- User-facing copy and action labels are localized in English and Spanish.

## Confirmed design direction

- Use the existing Carecierge app shell and stone/white/emerald styling as the primary visual authority.
- The account-owner surface is a calm chronological timeline grouped by date with plain-language explanations.
- Account-owner date filters, group headings, and timestamps use the account's saved notification time zone, with the application zone as fallback.
- The admin surface is a denser, paginated ledger with account, date, action, and source filters.
- Amber is limited to security-attention events and red to deletion events; neither color is the sole carrier of meaning.
- Mobile history rows reflow into labeled stacked content without horizontal scrolling; controls keep 44-pixel minimum touch targets and visible focus treatment.
- Generated visual probes are structural references only. Production output remains semantic ERB/Tailwind and does not include raster UI assets or the mocks' invented navigation.

## Implementation boundaries

- `AuditEvent` owns the immutable, privacy-minimized event contract and the supported action/source/actor catalogs.
- `AuditEvents::Track` owns transactionally pairing an existing mutation with a generic audit event.
- Existing specialized `AutomationPermissionChange` and `VaultAccessEvent` evidence remains intact; those workflows additionally emit the generic ledger event used by history views.
- `AuditEvents::Query` owns allowlisted filtering and ordering; controllers remain HTTP, authorization, and pagination adapters.
- Pundit enforces admin access. The ordinary history route always starts from `current_user.audit_events`, even for admins, so it cannot become a cross-account view accidentally.
- Polymorphic targets are optional and privacy-minimized. Their display is type-aware and falls back to a localized deleted-resource label when the target no longer exists.
- This ticket instruments the existing calendar export endpoints but does not add new export, deletion-request, vendor, booking, purchase, messaging, or AI-extraction product flows.

## Repository memory context

- Systems: `authentication`, `relationship_profiles`, `reminders`, `automation_permissions`
- Claims: `authentication.account_access_boundary`, `relationship_profiles.profile_crud_owner_scope`, `relationship_profiles.privacy_vault`, `reminders.reminder_delivery_system`, `automation_permissions.permission_decisions`, `agent_workflow.local_ci_signoff_gate`
- New durable system target: `audit_events`
- Required verification: `bin/memory context --git-diff`, focused RSpec, `bin/rubocop`, `bin/memory validate`, `bin/memory compile`, `bin/memory doctor`, `bin/memory coverage --git-diff`, `bin/memory audit --git-diff`, `CI_SIGNOFF=false bin/ci` before publication, and plain `bin/ci` after the pushed head exists.

## Risks

- Cross-account leakage through a broad policy scope or forged account filter.
- Arbitrary JSON metadata becoming a covert sensitive-content store.
- Audit insertion succeeding without its mutation, or a mutation succeeding without its required audit evidence.
- Generic audit integration changing the privacy vault's intentional best-effort behavior for access-only events.
- Polymorphic targets retaining stale identifiers or labels after source records are deleted.
- Unbounded admin queries or mobile tables becoming unusable at realistic history volumes.

## Review record

- Codex review pass 1 found and drove fixes for onboarding profile creation,
  global-ledger index coverage, and the unbounded admin account selector.
- Codex review pass 2 found and drove the admin relationship-name redaction;
  account owners still receive meaningful names in their private timeline.
- Codex review pass 3 found and drove durable privacy-vault relationship targets
  plus account-time-zone filtering, grouping, and rendering. The three-pass
  bounded review allowance is exhausted; no fourth Codex review will run.
- Final local verification after the expanded-cycle pass-3 fixes: 833 RSpec
  examples passed with 97.36% line and 82.03% branch coverage; RuboCop inspected
  435 files with no offenses;
  ESLint and Brakeman passed; `git diff --check`, agent-memory validation,
  synchronization, compilation, doctor, diff coverage, and diff audit passed.
- The repository dependency advisories were initially outside CAR-69 scope;
  the user explicitly approved resolving them before publication. Rails and its
  framework gems moved from 8.1.3 to 8.1.3.1, Loofah from 2.25.1 to 2.25.2,
  rails-html-sanitizer from 1.7.0 to 1.7.1, and DOMPurify from 3.4.11 to 3.4.13.
  `package.json` pins brace-expansion 5.0.9 through a transitive override because
  Bun otherwise retained the vulnerable 5.0.6 resolution allowed by minimatch.
- Fresh delivery cycle review pass 1 found that new files were absent from the
  base diff; intent-to-add now exposes the complete 47-file patch to review.
- Fresh delivery cycle review pass 2 found and drove fixes for false no-op update
  evidence and unbounded ISO date filters. Regression coverage passes.
- Fresh delivery cycle review pass 3 inspected the complete 47-file patch and
  found no actionable correctness, authorization, tenancy, localization, or
  regression issues. The fresh three-pass review allowance is exhausted.
- After the user-approved dependency remediation expanded the patch, a new
  bounded review cycle inspected the complete branch. Pass 1 found that the
  existing single and bulk reminder-calendar exports did not emit the required
  `data_export.requested` event; both endpoints now have request-level regression
  coverage for privacy-minimized audit evidence.
- Expanded-cycle pass 2 found and drove target-row serialization against
  concurrent deletion, post-normalization profile no-op detection, and an
  account target for bulk calendar exports so intentional targetless events are
  not presented as deleted resources. Each correction has regression coverage.
- Expanded-cycle pass 3 found that Turbo prefetches could create false calendar
  export evidence and that non-scalar filter parameters could be dropped before
  validation and silently broaden both ledgers. Export links now opt out of
  prefetching, server-identified prefetches do not create evidence, and raw
  allowlisted filter values reach fail-closed scalar validation. Regression
  coverage passes. The three-pass allowance is exhausted, so publication now
  requires explicit approval for a fresh bounded review cycle.
- The user approved a fresh bounded review cycle after those fixes. Fresh-cycle
  pass 1 reviewed the complete 57-file branch and found no actionable
  correctness, security, tenancy, localization, or regression issues. Its
  focused 123 examples passed; the partial-suite command exited only because
  repository-wide coverage thresholds require the full suite. The branch is
  clean for publication without additional review passes.
