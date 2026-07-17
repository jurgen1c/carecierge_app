# 10.1 Privacy Vault

**Area:** 10. Privacy, Safety, and Control

Users can protect sensitive relationship data.

## CAR-67 Baseline

The first production baseline protects individual relationship notes, memory
records, and relationship field values. Protected values move into an
application-encrypted `PrivacyVaultItem` payload; their ordinary source record
is redacted so profile rendering and search cannot recover the plaintext by
accident. Relationship-note categories are redacted and restored with their
body. Memory revision history is redacted and restored with its memory, and
ordinary profile or memory writes serialize against vault transitions so a
stale edit cannot put plaintext back after protection. If a custom relationship
field label is reused while the field is protected, restoration keeps the new
field and gives the restored field a localized disambiguated label.
Rich-text notes with embedded files are rejected without mutation so protection
cannot purge or leave attachments outside the encrypted boundary.

Opening the vault requires the signed-in user to re-enter their Carecierge
password. A successful check grants a session- and password-bound lease that
expires after 10 minutes of inactivity. Users can lock the vault immediately.
Explicit locking increments a server-checked per-user lease version so stale
cookies from concurrent tabs cannot reopen the vault. Password changes and
logout invalidate the lease. Unlock attempts are
rate-limited, and Google-authenticated users who do not know their generated
Carecierge password can use the normal password-reset flow to establish one.
Vault and protectable profile pages opt out of Turbo snapshot caching so Back
navigation cannot restore stale plaintext after protection, explicit locking,
or lease expiry. The unlocked vault also removes decrypted DOM content when
the inactivity lease ends and propagates explicit lock signals across browser
tabs before requiring a fresh server-authorized render.

Each protected item is excluded from future suggestion inputs by default. An
unlocked user can explicitly allow an item for suggestions, reverse that
choice, or restore the item to its ordinary profile surface. Suggestion changes
serialize with restoration and commit atomically with their audit event.
Uncategorized note titles use a stable type key and localize when displayed.
Metadata-only access events record unlock success/failure, locking, first-party viewing, item
protection/restoration, and suggestion-preference changes without storing
passwords or protected content.

Active Record Encryption encrypts the payload before PostgreSQL persistence.
Its primary, deterministic, and derivation keys may come from dedicated
`CARECIERGE_ACTIVE_RECORD_ENCRYPTION_*` environment variables or Rails
credentials; when neither is configured, the application derives separate
keys from `secret_key_base`. Deployments must keep whichever key source they
first use stable so existing vault payloads remain decryptable.
Rollback refuses to drop a populated vault table because those encrypted
payloads are the only recoverable copy of redacted source content.

## Capabilities

- Lock specific profiles.
- Lock specific notes.
- Mark data as sensitive.
- Require biometric/PIN re-authentication.
- Hide sensitive data from general search.
- Exclude sensitive data from AI processing if requested.
- Export/delete sensitive data.

Profile-wide locking, biometric authentication, vault export, and vault-aware
data deletion remain later scope. Authenticator-app MFA enrollment, TOTP
verification, recovery codes, and lost-device handling are specified in
[CAR-82](https://wecla.atlassian.net/browse/CAR-82).

## Possible Data Objects

- `PrivacyVaultItem`
- `VaultAccessEvent`

## Implementation Notes

Privacy is a core trust requirement. Relationship data can be highly sensitive.
