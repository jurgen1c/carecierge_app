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
Every request records the source version that was presented. Source edits bump
the request lock and refresh eligible work, while work that becomes ineligible
is marked superseded without inventing a user decision. Decisions recheck that
source version under the relationship and source locks, and an explicit source
review carries the refreshed request version into the canonical mutation.
Protected memory stays outside the queue, owner-entered deferral times use the
owner's saved time zone, and an explicitly selected owned item is resolved from
the active status scope independently of the current page. Edit/defer mode links
preserve that page through failed submissions. Replaying the matching completed
extracted-memory decision or successful high-impact memory approval is a no-op
and does not append duplicate history. A mismatched terminal retry and other
ineligible source controls return localized feedback without mutation.

Queue visits reconcile bounded batches of current source snapshots and open
requests. Sources without a current snapshot remain eligible for a later batch,
while open-request reconciliation selects only work that is no longer eligible,
so unchanged work cannot starve a later obsolete item. Queue synchronization
uses a no-key account lock before relationship so decision evidence can take its
foreign-key lock safely. Request kind, risk, confidence, and source version are
derived only after the relationship and source have been locked and reloaded.
Explicit source controls keep request discovery and
application atomic under relationship/source locks without acquiring account,
and accept only the source surface's approve, reject, or correct vocabulary.

Completed extracted-memory approvals present the corrected title that was
actually saved rather than the superseded proposal title.

The queue is an explicit review boundary, not an execution engine. Approving a
high-impact memory only allows that fact to support a later, separately approved
action; it does not contact, book, buy, pay, invite, send, or run automation.
Future item types require an allowlisted action adapter, owner validation,
localized consequence and non-effect copy, audit-safe metadata, and tests before
they may enter the queue.
