# 9.2 Social Media Context Helper

**Area:** 9. Communication and Social Context

Users can manually record a rich-text note with up to three PNG, JPEG, or WebP
screenshots and explicitly ask Carecierge for a cautious interpretation draft.
Carecierge does not connect to or monitor social accounts.

## Capabilities

- Keep manually provided relationship-scoped notes and screenshots.
- Bound stored rich-text HTML to 64 KiB and accept images only as PNG, JPEG, or
  WebP Active Storage attachments; reject raw remote and data-URL images.
- Require authentication when issuing and using short-lived direct-upload
  credentials, proxy storage writes through the owner-locked application
  endpoint, stamp each upload only in its server-resolved owner column, and
  accept a screenshot only when that owner matches the relationship account.
  Schedule retrying cleanup for uploads still unattached after one hour. Detect PNG,
  JPEG, or WebP from the stored bytes instead of trusting client-declared
  filenames or MIME metadata. Keep this bounded endpoint specific to social
  context so existing Lexxy attachment types retain their prior upload contract.
- Render saved screenshots and unattached editor previews only through an
  authenticated, owner-authorized, no-store response. Use a stored 1024-by-768
  bounded variant and lazy browser loading; never expose permanent Active Storage
  blob URLs or duplicate owner identifiers in blob metadata.
- Recheck stored image bytes when a note source is created or changed. Consent
  revocation and selective AI-data clearing keep enforcing saved ownership and
  size metadata without rereading unchanged storage, so an unavailable
  screenshot cannot leave downstream use or AI analysis stuck on.
- Keep the editor-heavy ledger bounded to five notes per page while reusing a
  ten-note opted-in source collection for downstream drafting and suggestions.
- Analyze only after an explicit save-and-analyze action and the configured
  automation permission. The action saves the submitted editor state before
  snapshotting and sending that saved revision.
- Snapshot the exact bounded note text and screenshot identities under the note
  lock before provider I/O. Save and Analyze actions carry the revision rendered
  to the user, so a newer edit invalidates the stale action before provider I/O.
- Present AI output and its proposed use categories as an editable Carecierge
  interpretation draft, never as fact; approval covers only the categories the
  user leaves selected.
- Allow a reviewed note to inform private suggestions and message drafts only when
  the user enables downstream use; the setting is off by default and revocable.
- Derive gift, message, conversation-topic, and reminder ideas only from an
  approved interpretation. Message drafting may use the user's own opted-in note
  before interpretation approval, but never an unapproved AI draft.
- Preserve separate user-provided and AI-inferred provenance when an approved
  interpretation supplements message-drafting context, and include that
  interpretation only when the user left the message-draft use selected.
- Fence message generation with the relationship-profile lock and generation
  version so revoking, editing, adding, reanalyzing, or deleting eligible social
  context prevents an older in-flight provider result from being persisted.
  Reanalysis clears the prior interpretation and advances its note and message
  fences before provider I/O begins.
- Persist completed analysis under the account, relationship-profile, and note
  locks in that order, without holding those locks across provider I/O, so it
  remains compatible with account and selective-AI deletion.
- Recheck that the relationship profile remains active while holding its lock for
  every note mutation, and surface provider or attachment-read failures as
  localized analysis errors without exposing storage details.
- Link suggestion evidence to the paginated ledger page that contains its source.
- Permanently delete a note and its unshared uploads, and include both in portable
  data exports.
- Preserve user-authored notes and uploads during selective AI-data deletion
  while clearing interpretation text, review state, proposed uses, and analysis
  timestamps; advance note and message-generation fences before delayed AI output
  can return.
- Snapshot note, profile, account screenshot, and unattached owner-stamped upload
  blobs while the relevant account and relationship profiles are locked, revoke
  outstanding grants with account deletion, then synchronously remove unshared
  storage before marking deletion evidence complete.

## Possible Data Objects

- `SocialContextNote`
- `Suggestion` with a `SocialContextNote` evidence source

## Implementation Notes

Avoid covert monitoring, platform scraping, sensitive-trait inference, or
automatic outreach. Analysis uses the OpenAI Responses API with `store: false`;
set `OPENAI_API_KEY` and optionally `CARECIERGE_SOCIAL_CONTEXT_MODEL` (default:
`gpt-5-mini`). Uploaded input may still be retained temporarily by the provider
for abuse monitoring under its data controls, so the interface must keep analysis
user-initiated and permission-gated.
