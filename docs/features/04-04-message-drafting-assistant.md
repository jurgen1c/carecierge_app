# 4.4 Message Drafting Assistant

**Area:** 4. AI Assistance and Intelligence

AI helps users draft thoughtful messages.

## Capabilities

- Generate birthday messages.
- Generate apologies.
- Generate thank-you notes.
- Generate check-ins.
- Generate congratulations.
- Generate condolences.
- Generate professional follow-ups.
- Generate invitations.
- Generate boundary-setting messages.
- Let user select tone.
- Let user edit before use.
- Keep generated, edited, and restored revisions as an immutable history.
- Restore an earlier revision by creating a new current revision.

## Tone Options

- Warm
- Funny
- Romantic
- Professional
- Concise
- Emotional
- Apologetic
- Casual
- Formal
- Encouraging

## Data Objects

- `MessageDraft`
- `DraftRevision`

## Context and Privacy

The assistant is profile-first. By default it can use only current,
owner-scoped, non-protected profile details, important dates, preferences,
public notes, and reviewed memory records. Contact details, archived or stale
memory, protected records, and vault contents are excluded.

Preference and memory context carries its confidence and available source
metadata into the provider request. Inferred, low-confidence, and AI-inferred
context is explicitly presented as tentative rather than established fact.

Draft generation and mutation are available only for active relationship
profiles; archived profile pages omit the drafting workspace. The active state
is rechecked under the profile lock before generated, edited, or restored text
can append a revision, so a concurrent archive wins. Context is capped at 6,000
characters and each complete source entry, including its label, is capped at
1,000 characters. When sensitive sources are explicitly selected, the first
eligible private-note and vault entries receive priority so ordinary long-form
context cannot silently displace the authorized sensitive categories or their
audit evidence.

Private notes are included only when the user selects them for that generation.
Privacy-vault context requires both an explicit selection and an active
password-backed vault lease. Its owner, password fingerprint, revocation version,
and inactivity deadline are revalidated under the account lock immediately before
context decryption. Sensitive-context access emits metadata-only audit
evidence; draft content is never copied into audit metadata.

## Generation and Review

Generation uses the OpenAI Responses API synchronously with `store: false` and
credentials resolved from Rails encrypted credentials before environment
fallbacks. The request carries an explicit English or Spanish output-language
instruction from the current Rails locale. Relationship context is bounded,
JSON-serialized as a distinct untrusted data value, and treated so embedded
instructions cannot override the drafting prompt. Completed responses aggregate
all output-text parts in provider order; only well-formed results can become
revisions.
Incomplete or malformed successful responses and expected TLS or HTTP protocol
failures leave existing draft state unchanged and use the same safe, localized
provider error. Submitted draft content is filtered from Rails parameter logs.

Each relationship profile has at most one draft workspace. Generating, saving
an edit, or restoring history appends a new immutable `DraftRevision`; it never
rewrites an earlier version. The profile page renders revision history in
newest-first pages of ten while keeping the editor bound to the current revision.
Deleting a workspace advances a profile-scoped generation version, so an older
in-flight provider response cannot recreate the deleted draft.
Drafts and revisions are included in the owner's
data export and are deleted with their profile or account.

Production can override the drafting model with
`CARECIERGE_MESSAGE_DRAFTING_MODEL`; Kamal forwards that variable with the same
`gpt-5-mini` default used by the application.

## Safety Boundary

The assistant is draft-only. It has no send, delivery, recipient, scheduling,
or external-action path. The user must review and edit the text before copying
or otherwise using it.
