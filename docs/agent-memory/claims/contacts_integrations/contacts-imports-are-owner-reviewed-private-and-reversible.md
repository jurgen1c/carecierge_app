---
id: contacts_integrations.contacts_imports_are_owner_reviewed_private_and_reversible
type: fact
system: contacts_integrations
status: current
confidence: verified
severity: critical
title: Contacts imports are owner reviewed private and reversible
claim: >
  Owner-controlled Google Contacts access uses a separate deployment-verified Cloud project, read-only scope, encrypted credentials, and owner-bound single-use expiring OAuth state with a generation fence. Nothing becomes a profile until an explicit create or link. Bounded manual fetches stage encrypted reviewed fields and never overwrite profiles. Versioned decisions offer owner-scoped duplicate matches and explicit duplicate overrides; links preserve existing fields, imports use the editable personal-phone kind, updates explicitly persist changed or removed contact methods with prior identity and preference metadata retained for undo and reject intervening edits, and undo preserves the original create or link decision while restoring an update, removes a link, or archives a created profile without erasing later history. Owner-first locks and access_contacts permission checks protect fetch and import, including profile overrides. Local undo and skip remain available when provider authorization or cleanup is blocked; new imports, links, updates and fetches require an active connection. Disconnect erases staged data only after revocation succeeds; failure retains blocked credentials for retry. Callback persistence failures revoke or retain encrypted cleanup credentials, and rollback after successful revocation fences restored connections. Permanent profile deletion erases local applied and undo snapshots, resets the staged decision and advances its version while retaining independently fetched provider data for explicit reimport. Account deletion preserves the owner on revocation failure. Exports include safe review data but exclude credentials and opaque provider identifiers. Selected profiles retain only provider, local import reference and timestamp after disconnect. Count-only audit evidence, no-store responses and English/Spanish controls preserve privacy and reviewability.
source_files:
  - app/models/contacts_connection.rb
  - app/models/imported_contact.rb
  - app/models/user.rb
  - app/models/relationship_profile.rb
  - app/models/audit_event.rb
  - app/controllers/contacts_connections_controller.rb
  - app/policies/contacts_connection_policy.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_account.rb
  - app/views/dashboard/index.html.erb
  - app/views/relationship_profiles/show.html.erb
  - app/views/components/contacts_connection_component.rb
  - app/views/components/contacts_connection_component.html.erb
  - app/views/contacts_connections/show.html.erb
  - config/routes.rb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/contacts.en.yml
  - config/locales/contacts.es.yml
  - config/deploy.yml
  - .kamal/secrets
  - db/schema.rb
  - db/migrate/20260905055742_create_contacts_integration.rb
  - docs/features/11-02-contacts-integration.md
  - app/services/contacts/disconnect.rb
  - app/services/contacts/google.rb
  - app/services/contacts/error.rb
  - app/services/contacts/google_oauth.rb
  - app/services/contacts/matches.rb
  - app/services/contacts/connect.rb
  - app/services/contacts/oauth_state.rb
  - app/services/contacts/decide.rb
  - app/services/contacts/permission.rb
  - app/services/contacts/refresh.rb
related_files:
  - spec/requests/contacts_connections_spec.rb
  - spec/services/contacts/decide_spec.rb
  - spec/services/contacts/provider_spec.rb
  - spec/services/contacts/google_spec.rb
  - spec/services/contacts/google_oauth_spec.rb
  - spec/system/contacts_connections_spec.rb
symbols:
  - Contacts::Connect
  - Contacts::Disconnect
  - Contacts::Refresh
  - Contacts::Decide
routes:
  - GET /contacts_connection
  - GET /contacts_connection/new
  - GET /contacts_connection/callback
  - POST /contacts_connection/refresh
  - POST /contacts_connection/decide/:contact_id
  - DELETE /contacts_connection
tags:
  - contacts_integrations
  - privacy
  - oauth
verification:
  - bundle exec rspec spec/services/contacts spec/requests/contacts_connections_spec.rb spec/system/contacts_connections_spec.rb
  - bin/ci
last_verified_commit: 4c9049c4a9a0b57541dfeafc18ebf12dba6a7f05
---

# Contacts imports are owner reviewed private and reversible

Owner-controlled Google Contacts access uses a separate deployment-verified Cloud project, read-only scope, encrypted credentials, and owner-bound single-use expiring OAuth state with a generation fence. Nothing becomes a profile until an explicit create or link. Bounded manual fetches stage encrypted reviewed fields and never overwrite profiles. Versioned decisions offer owner-scoped duplicate matches and explicit duplicate overrides; links preserve existing fields, imports use the editable personal-phone kind, updates explicitly persist changed or removed contact methods with prior identity and preference metadata retained for undo and reject intervening edits, and undo preserves the original create or link decision while restoring an update, removes a link, or archives a created profile without erasing later history. Owner-first locks and access_contacts permission checks protect fetch and import, including profile overrides. Local undo and skip remain available when provider authorization or cleanup is blocked; new imports, links, updates and fetches require an active connection. Disconnect erases staged data only after revocation succeeds; failure retains blocked credentials for retry. Callback persistence failures revoke or retain encrypted cleanup credentials, and rollback after successful revocation fences restored connections. Permanent profile deletion erases local applied and undo snapshots, resets the staged decision and advances its version while retaining independently fetched provider data for explicit reimport. Account deletion preserves the owner on revocation failure. Exports include safe review data but exclude credentials and opaque provider identifiers. Selected profiles retain only provider, local import reference and timestamp after disconnect. Count-only audit evidence, no-store responses and English/Spanish controls preserve privacy and reviewability.
