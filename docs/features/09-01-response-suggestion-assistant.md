# 9.1 Response Suggestion Assistant

**Area:** 9. Communication and Social Context

The existing relationship-profile message-draft workspace suggests responses
to messages, situations, or social posts. It remains one private, revisioned
workspace rather than creating a parallel response-suggestion store.

## Capabilities

- The user can paste a message or describe a situation and the purpose of the
  response.
- The app adapts the suggestion to the selected non-overlapping tone, length, formality, and
  current relationship type and context.
- The message or situation is bounded to 4,000 characters and filtered from
  Rails parameter logs.
- The user reviews and edits every suggestion before using it.
- Generated, edited, and restored text remains in immutable revision history;
  the current response settings remain in the profile's draft workspace.
- Validated private response settings are retained if provider generation fails,
  while no failed response becomes a revision.
- When requests overlap, the latest request owns the saved settings and is the
  only request allowed to append its response.
- Saving an edit or restoring history supersedes any older in-flight request.
- The workspace never sends, addresses, schedules, or delivers a message.

## Response Types

- Birthday
- Apology
- Thank-you
- General reply or check-in
- Congratulations
- Condolence
- Professional follow-up
- Invitation
- Boundary-setting

## Data Objects

- `MessageDraft` retains the message or situation plus current purpose, tone,
  response length, and formality.
- `DraftRevision` retains each generated, edited, or restored response.

## Context and Safety

Current non-protected relationship context is eligible by default. Private
notes require explicit selection, while privacy-vault items require both
explicit selection and a live password-backed vault lease. The message or
situation and relationship context are separately JSON-serialized as untrusted
provider input, cannot override the system instructions, and are never copied
into audit metadata.

Provider instructions prohibit manipulative, coercive, pressuring, guilt-based,
or deceptive language. The interface states that nothing is sent automatically
and that the user remains responsible for the final message.

## Implementation Notes

This feature extends the message-drafting assistant described in
`04-04-message-drafting-assistant.md`; do not add a second provider or delivery
path for response suggestions.
