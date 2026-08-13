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
- Suggest a response to a pasted message or described situation.
- Let user select tone.
- Let user select response length and formality independently from tone.
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
- Encouraging

## Data Objects

- `MessageDraft`
- `DraftRevision`

## Context and Privacy

The assistant is profile-first. By default it can use only current,
owner-scoped, non-protected profile details, including visible structured
relationship fields, important dates, preferences, public notes, and reviewed
memory records. Hidden relationship fields, contact details, archived or stale
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
Validated purpose, tone, response length, formality, and message-or-situation
settings are saved before the provider request so a provider failure does not
discard the user's private input. Incomplete or malformed successful responses
and expected TLS or HTTP protocol failures do not append a revision and use the
same safe, localized provider error. Submitted draft content is filtered from
Rails parameter logs. Tone describes emotional character and excludes the
casual/formal values owned by the independent formality setting; existing
casual/formal tones remain intact for older application processes and rollback
safety. The new application treats those rows as warm tone and interprets the
legacy value as formality through its effective-value compatibility mapping.
Rows are not copied during the rolling-deploy window, so a later old-process tone
change cannot leave a stale formality value behind. A later cleanup can migrate
the legacy values after old processes are fully drained.
Each request advances the profile generation fence after saving its settings,
so a newer request supersedes any older in-flight provider response. Only the
latest request can append a revision, keeping its response and settings aligned.
Saving an edit or restoring a revision also advances the fence, so late provider
responses cannot displace a newer user-selected current revision.

Each relationship profile has at most one draft workspace. The workspace keeps
the current purpose, tone, response length, formality, and a bounded optional
message-or-situation input. Generating, saving
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
or otherwise using it. Provider instructions reject manipulative, coercive,
pressuring, guilt-based, and deceptive language, and the interface keeps the
user responsible for the final message.
