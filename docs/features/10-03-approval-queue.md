# 10.3 Approval Queue

**Area:** 10. Privacy, Safety, and Control

High-impact actions require user approval.

## Approval Item Types

- Message draft
- Vendor message
- Quote request
- Booking confirmation
- Purchase request
- Deposit payment
- Invitation
- Calendar invite
- Extracted memory

## Capabilities

- Review pending approvals.
- Approve.
- Reject.
- Edit before approving.
- Snooze.
- View reason/source.
- Track completed approvals.
- Defer an item until a future review time.
- Dismiss an item without changing its source.
- Explain what approval will and will not do, plus reversibility.

## Possible Data Objects

- `ApprovalRequest`
- `ApprovalStatus`
- `ApprovalAction`
- `ApprovalAuditEntry`

## Implementation Notes

The queue uses owner-scoped `ApprovalRequest` envelopes and append-only
`ApprovalDecision` history without copying private source content. It currently
adapts pending extracted-memory proposals and blocked high-impact memory facts.
Both queue decisions and the existing source controls converge on the same
underlying object state and decision history. Rejected or dismissed work stays
out of the active queue until its source changes. A source control used after
deferral is treated as a current explicit decision and closes the deferred item;
a source control used after a terminal decision creates a new request envelope
so the reversal remains visible in the append-only history.
Every open request records the source version that was presented. Source edits
bump the request lock and refresh eligible work, while work that becomes
ineligible is marked superseded without inventing a user decision. Superseded
work can re-enter the queue when temporary ineligibility ends even if the source
itself was not edited; rejected or dismissed work still requires a source
change. Completed superseded items use neutral automatic-transition copy rather
than presenting the transition as an approval decision. Decisions recheck the presented version under the relationship and
source locks, refresh confidence and risk together when explicitly accepting a
changed version, then bind a completed envelope to the resulting source version.
If that source changes later, or an approved extracted memory's canonical record
moves into the privacy vault, completed history shows an explicit earlier-
version state instead of attributing mutable or protected content to the old decision.
Completed extracted-memory history also uses a neutral reviewed-source label
instead of rendering mutable conversation-recap metadata. Completed pages
preload canonical memory and vault state before evaluating those masks.
Protected memory stays outside the queue, owner-entered deferral times,
scheduled return times, and displayed queue evidence use the owner's saved time
zone. On narrow layouts, the selected approval appears before the bounded queue
rail so the current decision remains immediately reachable. Deferral inputs use
a safely rounded future-minute minimum. A due deferral returns to pending
before an explicitly accepted source-version refresh is persisted, while an
invalid deferred envelope without a review time fails closed instead of
rendering decision controls or raising. An
explicitly selected owned item is resolved from
the active status scope independently of the current page. Edit/defer mode links
preserve that page through failed submissions. Replaying the matching completed
extracted-memory decision or successful high-impact memory approval is a no-op
and does not append duplicate history. Corrected-memory retries are idempotent
only when their normalized title and body match the saved correction. A mismatched terminal retry and other
ineligible source controls return localized feedback without mutation.

Queue visits reconcile bounded batches of current source snapshots and open
requests. Sources without a current snapshot remain eligible for a later batch,
while open-request reconciliation selects only work that is no longer eligible,
so unchanged work cannot starve a later obsolete item. Open envelopes whose
polymorphic source disappeared are removed before reconciliation and rendering.
Queue synchronization
uses a no-key account lock, preselects only bounded candidate work, and locks
every involved relationship in UUID order before source processing. Candidate
relationships are preloaded in one query before that order is built. The batch
reuses those relationship locks, reattaches the locked profile after each source
reload, and loads privacy-vault state once before
per-source revalidation. This keeps
the order compatible with other multi-profile workflows while allowing decision
evidence to take its foreign-key lock safely. Request kind, risk, confidence,
and source version are derived only after the relationship and source have been
locked and reloaded.
Explicit source controls keep request discovery and
application atomic under compatible no-key account/relationship/source locks,
and accept only the source surface's approve, reject, or correct vocabulary.

Completed extracted-memory approvals present the corrected title that was
actually saved rather than the superseded proposal title.

The queue is an explicit review boundary, not an execution engine. Approving a
high-impact memory only allows that fact to support a later, separately approved
action; it does not contact, book, buy, pay, invite, send, or run automation.
Future item types require an allowlisted action adapter, owner validation,
localized consequence and non-effect copy, audit-safe metadata, and tests before
they may enter the queue.
