---
id: relationship_profiles.privacy_vault
type: fact
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Privacy vault encrypts and gates sensitive relationship context

claim: >
  Owner-scoped notes, memories, and relationship fields can move into an Active
  Record Encryption-backed PrivacyVaultItem. Protection redacts ordinary sources
  and memory revisions, excludes normal search and suggestions by default, and
  serializes against stale plaintext writes. Opening requires a fresh password and
  grants a rate-limited, password-bound 10-minute inactivity lease. Explicit lock
  uses a server-checked per-user version to revoke issued cookie leases. Sensitive
  pages disable Turbo snapshots, send HTTP no-store, and remove decrypted DOM
  content on a response-relative timer or a cross-tab signal from UI lease
  revocations. Password recovery signs authenticated users out and revokes the
  lease before handing off to Devise. Unlocked users can reveal, restore, or allow
  an item for suggestions; VaultAccessEvent stores metadata only. The vault
  migration refuses rollback while encrypted payloads remain.

source_files:
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
  - app/policies/privacy_vault_item_policy.rb
  - app/views/privacy_vaults/show.html.erb
  - app/views/privacy_vaults/_section.html.erb
  - config/initializers/active_record_encryption.rb
  - db/migrate/20260716125513_create_privacy_vault_items.rb
  - db/migrate/20260716125514_create_vault_access_events.rb
  - db/migrate/20260716125515_add_privacy_vault_lease_version_to_users.rb

related_files:
  - docs/features/10-01-privacy-vault.md
  - spec/models/privacy_vault_item_spec.rb
  - spec/services/privacy_vault/protect_spec.rb
  - spec/policies/privacy_vault_item_policy_spec.rb
  - spec/requests/privacy_vaults_spec.rb
  - spec/system/privacy_vault_spec.rb
symbols:
  - PrivacyVaultItem
  - VaultAccessEvent
  - PrivacyVault::Payload
  - PrivacyVault::Protect
  - PrivacyVault::Restore
  - PrivacyVaultItemPolicy
  - PrivacyVaultSession
  - PrivacyVaultsController
  - PrivacyVaultItemsController
  - PrivacyVaultController
routes:
  - relationship_profile_privacy_vault
  - unlock_relationship_profile_privacy_vault
  - reset_password_relationship_profile_privacy_vault
  - lock_relationship_profile_privacy_vault
  - relationship_profile_privacy_vault_items
  - relationship_profile_privacy_vault_item
tags:
  - vault_security
  - encryption
  - password_reauthentication

verification:
  - bundle exec rspec spec/models/privacy_vault_item_spec.rb spec/services/privacy_vault/protect_spec.rb spec/policies/privacy_vault_item_policy_spec.rb spec/requests/privacy_vaults_spec.rb
  - bundle exec rspec spec/requests/relationship_profiles_spec.rb spec/queries/relationship_profile/search_query_spec.rb spec/models/memory_record_spec.rb spec/policies/memory_record_policy_spec.rb spec/requests/memory_records_spec.rb
  - bundle exec rspec spec/system/privacy_vault_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff

last_verified_commit: null
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
Google-created accounts. Audits store metadata only. Authenticator MFA remains
deferred to CAR-82.

## Why It Matters

Relationship context can be deeply personal. Redacting ordinary sources and
requiring password reauthentication prevent an unattended signed-in session,
ordinary search, or future suggestion query from silently crossing the stronger
vault boundary. Encryption ensures PostgreSQL receives ciphertext rather than
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
