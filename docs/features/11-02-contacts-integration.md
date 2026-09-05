# 11.2 Contacts Integration

Carecierge offers owner-controlled Google Contacts import. The dashboard Contacts entry opens a private review surface. Connecting does not import profiles. The owner explicitly fetches up to 100 contacts per request and reviews saved contacts in pages of 20.

## Provider setup

Enable the Google People API and configure a web OAuth client in a **separate Google Cloud project** from Carecierge Google login and Calendar. Google revocation invalidates a project's combined grant, so merely adding a second client in the same project is insufficient isolation. Set `GOOGLE_CONTACTS_CLIENT_ID`, `GOOGLE_CONTACTS_CLIENT_SECRET`, and set `GOOGLE_CONTACTS_ISOLATED_PROJECT=true` only after verifying that isolation. Kamal forwards these variables; unset credentials or the isolation flag leave the provider unavailable and manual profile creation remains accessible. Register `/contacts_connection/callback` on the application's HTTPS origin. The integration requests only `https://www.googleapis.com/auth/contacts.readonly`, disables incremental combined authorization, and requests offline consent. Complete Google's consent-screen and verification requirements for the deployment audience before enabling access.

Provider protocol sources: [People connections list](https://developers.google.com/people/api/rest/v1/people.connections/list) and [Google OAuth revocation](https://developers.google.com/identity/protocols/oauth2/web-server#tokenrevoke).

## Review and updates

- Fetching stages encrypted names, one email, one phone, and a complete birthday date when Google supplies a year. No birth year is inferred for incomplete birthdays. Raw provider payloads, biographies, addresses, photos and notes are not stored.
- Create adds a profile of type Other with the reviewed fields, using the existing editable personal-phone field. Exact name, email or phone matches are offered explicitly, including an indication that an archived match exists. A separate duplicate requires an explicit override.
- Link associates an active matched profile without replacing its fields. Skip leaves the contact out of profiles. No contacts are messaged or written back to Google.
- Refresh updates only the staged provider snapshot. Apply reviewed update is explicit and refuses to overwrite profile fields that changed since the previous choice. Server-side review versions reject stale submissions.
- Undo removes a link, archives a created profile while retaining subsequent edits/history, or restores the last applied update including contact-method identity, label and preference when no intervening local edit would be overwritten. Archived profiles must be restored before applying updates.
- Disconnect revokes provider access and removes encrypted credentials and staged contacts. Selected profiles retain only the provider, local import reference, and import timestamp as source history. Account exports include review data and safe connection metadata, never OAuth credentials, provider identifiers or page tokens. Profile exports include their retained source history.

## Privacy and recovery

`access_contacts` is enforced before connection, each fetch, and each create/link/update, with relationship overrides on existing profiles. All reads and mutations are owner-scoped. Explicit owner actions satisfy ask-every-time; there is no scheduled synchronization. OAuth state is single-use, owner-bound, expiring and generation-fenced. Account-first locks serialize connection callbacks, profile writes and deletion. Failed revocation keeps credentials available for an explicit disconnect retry and blocks further use. Local rollback after completed revocation fences restored credentials as requiring authorization. Account deletion revokes contacts and calendar access before removal and preserves the account on failure.

Audit actions retain counts/results only. Review responses use no-store and disable Turbo snapshots. Google response bodies and contact fields are excluded from logs. User-facing controls remain available in English and Spanish, with English the default.

## Migration and verification

The additive migration creates UUID tables and references, unique per-owner connections, unique provider mappings, and a nullable profile reference cleared on deletion. The users generation column has a constant default; PostgreSQL can add it without rewriting existing rows, though DDL still briefly needs a table lock. Rollback removes the new integration tables and generation column; disconnect provider grants before rolling back a populated deployment.

Verify with `bundle exec rspec spec/services/contacts spec/requests/contacts_connections_spec.rb spec/system/contacts_connections_spec.rb`, `bin/memory validate`, `bin/memory sync`, and the complete `bin/ci` gate. `CAPTURE_CONTACTS_UI=true` captures desktop, tablet and mobile system-test screenshots.

Permanent profile deletion detaches imported contacts and erases applied/undo snapshots, including locally authored profile values. The decision returns to pending with a new version. Independently fetched provider fields remain available for a new explicit import until disconnect or account deletion. The existing owner-first deletion lock serializes this cleanup with contact decisions.

Provider authorization or cleanup failures do not prevent local undo or skip. The review surface keeps those cleanup choices available while blocking create, link, update and fetch until an active connection is restored.
