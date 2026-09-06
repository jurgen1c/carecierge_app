---
id: relationship_profiles.privacy_vault
type: fact
system: relationship_profiles
status: current
confidence: verified
severity: critical

title: Privacy vault encrypts and gates sensitive relationship context

claim: >
  Owner-scoped notes, memories, and relationship fields can move into an Active
  Record Encryption-backed PrivacyVaultItem. Protection redacts ordinary sources
  and memory revisions, excludes normal search and suggestions by default, and
  serializes against stale plaintext writes. Opening requires a fresh password and
  grants a rate-limited, password-bound 10-minute inactivity lease. Optional
  authenticator MFA additionally requires a fresh, unreplayed TOTP (current or
  previous 30-second period) or one unused recovery code, verified under the owner
  lock by PrivacyVault::Unlock. VaultMfaCredential encrypts the TOTP secret and
  stores ten independently salted BCrypt recovery digests. Enrollment requires
  password, session-bound expiring TOTP proof, once-only recovery display and saved-code
  acknowledgement. Regeneration requires fresh password plus TOTP; disablement
  accepts password plus TOTP or recovery and clears credentials. Both revoke leases.
  Five failed attempts across MFA verification routes impose a five-minute account
  limit that restarting enrollment cannot reset. Lost-device recovery has no
  support or password-reset bypass: without the authenticator or a recovery code
  the vault stays locked. OAuth users must establish a known password. Security
  identity changes and logout revoke leases and pending enrollment. The
  authoritative lease check-and-touch must succeed before decrypted data loads.
  Sensitive downstream context consumers revalidate the issued lease owner,
  password fingerprint, revocation version, and inactivity deadline under the
  account lock and serialize reads with vault mutations under the relationship-profile lock.
  Explicit lock uses a server-checked per-user version to revoke issued cookie leases. Sensitive
  pages disable Turbo snapshots, send HTTP no-store, and remove decrypted DOM
  content on a response-relative timer or a cross-tab signal from UI lease
  revocations. Password recovery signs authenticated users out and revokes the
  lease before handing off to Devise. Unlocked users can reveal, restore, allow
  an item for suggestions, or permanently delete its underlying protected
  record through the privacy-minimized deletion-request workflow;
  downstream gift recommendation context fails closed unless that per-item
  suggestion approval remains current as well as the lease.
  VaultAccessEvent stores metadata only. Access-event
  persistence is best-effort and reports failures without blocking password,
  lock, or view outcomes, while mutation-event persistence remains transactional.
  The vault migration refuses rollback while encrypted payloads remain; the MFA migration refuses rollback while any account has MFA enabled.

source_files:
  - app/models/vault_mfa_credential.rb
  - app/models/user.rb
  - app/controllers/vault_mfas_controller.rb
  - app/services/privacy_vault/unlock.rb
  - app/services/privacy_vault/verify.rb
  - app/services/privacy_vault/enrollment.rb
  - app/services/privacy_vault/manage_mfa.rb
  - app/policies/vault_mfa_credential_policy.rb
  - app/helpers/vault_mfas_helper.rb
  - app/views/vault_mfas/show.html.erb
  - app/views/components/vault_verification_fields_component.rb
  - app/views/components/vault_verification_fields_component.html.erb
  - config/locales/vault_mfa.en.yml
  - config/locales/vault_mfa.es.yml
  - db/migrate/20260905235653_create_vault_mfa_credentials.rb
  - app/models/privacy_vault_item.rb
  - app/models/vault_access_event.rb
  - app/controllers/concerns/privacy_vault_session.rb
  - app/controllers/privacy_vaults_controller.rb
  - app/controllers/privacy_vault_items_controller.rb
  - app/controllers/users/sessions_controller.rb
  - app/helpers/application_helper.rb
  - app/javascript/controllers/privacy_vault_controller.js
  - app/services/privacy_vault/payload.rb
  - app/services/privacy_vault/protect.rb
  - app/services/privacy_vault/change_suggestion_usage.rb
  - app/services/privacy_vault/restore.rb
  - app/services/privacy_vault/delete.rb
  - app/services/privacy_vault/lease.rb
  - app/policies/privacy_vault_item_policy.rb
  - app/views/privacy_vaults/show.html.erb
  - app/views/privacy_vaults/_section.html.erb
  - config/initializers/active_record_encryption.rb
  - db/migrate/20260716125513_create_privacy_vault_items.rb
  - db/migrate/20260716125514_create_vault_access_events.rb
  - db/migrate/20260716125515_add_privacy_vault_lease_version_to_users.rb

related_files:
  - Gemfile
  - Gemfile.lock
  - db/schema.rb
  - config/routes.rb
  - config/initializers/filter_parameter_logging.rb
  - spec/models/vault_mfa_credential_spec.rb
  - spec/services/privacy_vault/unlock_spec.rb
  - spec/services/privacy_vault/enrollment_spec.rb
  - spec/requests/vault_mfas_spec.rb
  - spec/system/vault_mfa_spec.rb
  - spec/policies/vault_mfa_credential_policy_spec.rb
  - docs/features/10-01-privacy-vault.md
  - spec/models/privacy_vault_item_spec.rb
  - spec/services/privacy_vault/protect_spec.rb
  - spec/services/privacy_vault/lease_spec.rb
  - spec/policies/privacy_vault_item_policy_spec.rb
  - spec/requests/privacy_vaults_spec.rb
  - spec/services/message_drafts/generate_spec.rb
  - app/services/gift_recommendations/context_builder.rb
  - spec/services/gift_recommendations/context_builder_spec.rb
  - spec/services/gift_recommendations/generate_spec.rb
  - spec/system/privacy_vault_spec.rb
symbols:
  - VaultMfaCredential
  - PrivacyVault::Unlock
  - PrivacyVault::Verify
  - PrivacyVault::Enrollment
  - PrivacyVault::ManageMfa
  - VaultMfasController
  - PrivacyVaultItem
  - VaultAccessEvent
  - PrivacyVault::Payload
  - PrivacyVault::Lease
  - PrivacyVault::Protect
  - PrivacyVault::Restore
  - PrivacyVault::Delete
  - PrivacyVaultItemPolicy
  - PrivacyVaultSession
  - PrivacyVaultsController
  - PrivacyVaultItemsController
  - PrivacyVaultController
routes:
  - vault_mfa
  - prove_vault_mfa
  - complete_vault_mfa
  - regenerate_vault_mfa
  - reset_password_vault_mfa
  - relationship_profile_privacy_vault
  - unlock_relationship_profile_privacy_vault
  - reset_password_relationship_profile_privacy_vault
  - lock_relationship_profile_privacy_vault
  - relationship_profile_privacy_vault_items
  - relationship_profile_privacy_vault_item
  - delete_data_relationship_profile_privacy_vault_item
tags:
  - vault_security
  - encryption
  - password_reauthentication

verification:
  - bundle exec rspec spec/models/vault_mfa_credential_spec.rb spec/services/privacy_vault/unlock_spec.rb spec/services/privacy_vault/enrollment_spec.rb spec/requests/vault_mfas_spec.rb spec/system/vault_mfa_spec.rb spec/policies/vault_mfa_credential_policy_spec.rb
  - bundle exec rspec spec/models/privacy_vault_item_spec.rb spec/services/privacy_vault/protect_spec.rb spec/policies/privacy_vault_item_policy_spec.rb spec/requests/privacy_vaults_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb
  - bundle exec rspec spec/system/privacy_vault_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff

last_verified_commit: 022581c95af508bf161ad3818a3b6cb7c00c3e1d
---

# Privacy vault encrypts and gates sensitive relationship context

## Claim

Owner-scoped notes, memories, and fields move into an encrypted payload while
their sources and revisions are redacted. Serialized transitions reject stale
plaintext; protected items stay out of ordinary views, search, and suggestions.
Embedded files remain unsupported and are rejected without mutation.

A fresh password grants a rate-limited 10-minute inactivity lease. Server-side
versions revoke stale cookies; decrypted responses use HTTP no-store, and the
browser uses a response-relative timer plus cross-tab UI revocation signals to
remove decrypted DOM content. Password recovery first signs the user out and
revokes the lease so Devise's unauthenticated recovery flow remains usable for
Google-created accounts. Audits store metadata only; access audit failures are
reported without blocking unlock, failed-unlock, lock, or view outcomes, while
protection and restoration audits remain transactional.

## Authenticator boundary

CAR-82 adds optional
TOTP MFA with encrypted secrets, independently salted one-way recovery codes,
owner-serialized verification and account-wide attempt limits. Enrollment
plaintext exists only in the immediate no-store response; credentials never
enter session cookies, logs, audit metadata, or owner exports. Completing
setup requires password, session-bound authenticator proof and recovery-code
acknowledgement. Without an authenticator or unused recovery code there is no
vault bypass; ordinary sign-in remains available. Verification audit failures
use a savepoint and cannot undo failed-attempt counters or lease revocation.
Initial enrollment proof also preserves the consumed TOTP period, verified
state, and recovery digests when an audit database statement fails;
lifecycle audit failures roll back the corresponding credential mutation.
Password recovery emits the same cross-tab concealment signal as other vault
security forms; displayed enrollment keys and recovery codes are removed by
the same signal on logout in another tab. Sensitive exports require a fresh
second factor with the password when enrolled, sharing replay and rate limits.
Enrollment secrets use the remaining enrollment display timer; regenerated
recovery codes are concealed within ten minutes through the same controller.
ApplicationHelper includes Devise's OmniAuth URL helpers so
the stock recovery view can render its shared provider links after sign-out.

## Why It Matters

Relationship context can be deeply personal. Redacting ordinary sources and
requiring password reauthentication prevent an unattended signed-in session,
ordinary search, or future suggestion query from silently crossing the stronger
vault boundary. Message drafting revalidates the complete password-backed lease
under the account lock and assembles context under the same relationship-profile lock used by
vault protection, so completed revocation and redaction win before decryption.
Encryption ensures PostgreSQL receives ciphertext rather than
the protected payload. A populated vault migration cannot roll back until its
items are restored, preventing deletion of the only recoverable encrypted copy.

## Evidence

- `app/models/privacy_vault_item.rb`
- `app/controllers/concerns/privacy_vault_session.rb`
- `app/services/privacy_vault/protect.rb`
- `app/services/privacy_vault/restore.rb`
- `app/controllers/privacy_vaults_controller.rb`
- `app/controllers/privacy_vault_items_controller.rb`
- `app/javascript/controllers/privacy_vault_controller.js`
- `spec/requests/privacy_vaults_spec.rb`

## Verification

- `bundle exec rspec spec/models/privacy_vault_item_spec.rb spec/services/privacy_vault/protect_spec.rb spec/policies/privacy_vault_item_policy_spec.rb spec/requests/privacy_vaults_spec.rb`
- `bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb`
- `bundle exec rspec spec/system/privacy_vault_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
