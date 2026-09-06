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
password and, when enrolled, a fresh authenticator or unused recovery code. A successful check grants a session- and password-bound lease that
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
data deletion remain separate scope.

## Authenticator MFA (CAR-82)

`/vault_mfa` is an owner-only security workspace linked from each vault.
Enrollment confirms the account password, generates a locally rendered QR/manual
key, requires a TOTP proof, displays ten recovery codes once, then requires
saved-code acknowledgement. Setup expires after ten minutes and is bound to the
current session, password, and account revocation version. Leaving the recovery
page without saving the codes requires restarting setup; plaintext is never
persisted in the database or cookie.

`VaultMfaCredential` encrypts its TOTP secret with Active Record Encryption and
stores independently salted BCrypt recovery digests. `PrivacyVault::Unlock`
verifies the password and second factor under the account lock before issuing
the existing lease. TOTP accepts the current and previous 30-second period and
persists the last accepted period to reject replay. Recovery consumption is
single-use. Five failures across MFA operations impose a five-minute account
limit; changing sessions or restarting enrollment does not reset it.

Replacing recovery codes requires a fresh password and TOTP, immediately revokes
old codes and vault leases, and displays the new set once. Disabling requires
password plus TOTP/recovery, clears the secret and codes, and revokes leases.
Password/email/OAuth identity/lock-state changes and logout revoke leases and
pending enrollment. Metadata-only audits record all MFA lifecycle and verification
outcomes. Verification audit failure cannot undo consumed factors, failure
counters or revocation; lifecycle audits commit with credential mutations.

An owner who loses a device can use a recovery code plus password to disable MFA
and enroll a replacement. Without either second factor the vault remains locked;
there is no support, ordinary-sign-in, or password-reset bypass. Google-created
accounts establish a known password through Devise recovery before setup or
recovery. Password resets preserve MFA. Users who have not enabled MFA retain
the existing password-only behavior. Credential secrets/digests are excluded
from owner exports. Rollback refuses to drop credentials while MFA is enabled.
Explicit sensitive exports also require a fresh password and second factor for
enrolled accounts, with the same replay and attempt limits. Verification and
protected snapshot reads hold the account lock together. Ordinary exports retain
their existing redaction. Another-tab logout removes displayed enrollment keys
and recovery codes from the page through the existing vault concealment signal.
The same controller conceals enrollment credentials at setup expiry and newly
regenerated recovery codes within ten minutes, even if the page is left open.

Verification: `bundle exec rspec spec/models/vault_mfa_credential_spec.rb
spec/services/privacy_vault spec/requests/vault_mfas_spec.rb
spec/requests/privacy_vaults_spec.rb spec/system/vault_mfa_spec.rb`.

## Possible Data Objects

- `PrivacyVaultItem`
- `VaultAccessEvent`

## Implementation Notes

Privacy is a core trust requirement. Relationship data can be highly sensitive.
