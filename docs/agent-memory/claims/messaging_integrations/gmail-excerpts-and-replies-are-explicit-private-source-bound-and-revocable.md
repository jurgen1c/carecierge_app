---
id: messaging_integrations.gmail_excerpts_and_replies_are_explicit_private_source_bound_and_revocable
type: constraint
system: messaging_integrations
status: current
confidence: high
severity: critical
title: Gmail excerpts and replies are explicit private source bound and revocable
claim: >
  Gmail access requires explicit-only account permission, owner/session-bound expiring OAuth state, an isolated Google project and an exact read-only grant. Owners explicitly search at most ten transient snippets and import individual encrypted, immutable, source-linked excerpts. Imported context never enters automatic AI memory extraction, relationship context builders, suggestions or vault sources. Reply generation requires explicit consent and drafting permission, sends only the selected snippet to the non-stored provider, and persists an encrypted local draft alongside its source. No send or external approval-action path exists. Account locks and draft versions serialize permission changes, generation and deletion. Local source deletion removes its draft independently of provider permission; disconnect deletes all imported context and revokes credentials with unusable encrypted retry state on failure. Exports exclude credentials, selective AI deletion clears generated communication drafts and edited derivatives while preserving manual-only replies, and account deletion compensates rolled-back grant revocation. Audit records retain result-only account evidence.
source_files:
  - .kamal/secrets
  - app/controllers/messaging_connections_controller.rb
  - app/models/audit_event.rb
  - app/models/automation_capability.rb
  - app/models/imported_message_context.rb
  - app/models/messaging_connection.rb
  - app/models/user.rb
  - app/policies/messaging_connection_policy.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_account.rb
  - app/services/data_deletions/delete_ai_data.rb
  - app/services/messaging/access.rb
  - app/services/messaging/connect.rb
  - app/services/messaging/delete_context.rb
  - app/services/messaging/disconnect.rb
  - app/services/messaging/draft.rb
  - app/services/messaging/edit_draft.rb
  - app/services/messaging/error.rb
  - app/services/messaging/google.rb
  - app/services/messaging/google_oauth.rb
  - app/services/messaging/import.rb
  - app/services/messaging/oauth_state.rb
  - app/services/messaging/permission.rb
  - app/views/components/messaging_connection_component.html.erb
  - app/views/components/messaging_connection_component.rb
  - app/views/dashboard/index.html.erb
  - app/views/messaging_connections/show.html.erb
  - config/deploy.yml
  - config/initializers/filter_parameter_logging.rb
  - config/locales/messaging.en.yml
  - config/locales/messaging.es.yml
  - config/routes.rb
  - db/migrate/20260905075430_create_messaging_foundations.rb
  - db/migrate/20260905080040_allow_messaging_permission.rb
  - db/migrate/20260905081335_add_draft_provenance_to_imported_message_contexts.rb
  - spec/models/automation_capability_spec.rb
  - db/schema.rb
  - docs/features/11-03-email-and-messaging-integrations.md
  - spec/requests/messaging_connections_spec.rb
  - spec/services/messaging/connect_spec.rb
  - spec/services/messaging/google_oauth_spec.rb
  - spec/services/messaging/google_spec.rb
  - spec/services/messaging/oauth_state_spec.rb
  - spec/services/messaging/workflow_spec.rb
  - spec/system/messaging_connections_spec.rb
tags:
  - messaging_integrations
  - privacy
  - oauth
verification:
  - bundle exec rspec spec/services/messaging spec/requests/messaging_connections_spec.rb spec/system/messaging_connections_spec.rb
  - bin/ci
  - bin/memory validate
last_verified_commit: null
---

# Gmail excerpts and replies

Gmail access requires explicit-only account permission, owner/session-bound expiring OAuth state, an isolated Google project and an exact read-only grant. Owners explicitly search at most ten transient snippets and import individual encrypted, immutable, source-linked excerpts. Imported context never enters automatic AI memory extraction, relationship context builders, suggestions or vault sources. Reply generation requires explicit consent and drafting permission, sends only the selected snippet to the non-stored provider, and persists an encrypted local draft alongside its source. No send or external approval-action path exists. Account locks and draft versions serialize permission changes, generation and deletion. Local source deletion removes its draft independently of provider permission; disconnect deletes all imported context and revokes credentials with unusable encrypted retry state on failure. Exports exclude credentials, selective AI deletion clears generated communication drafts and edited derivatives while preserving manual-only replies, and account deletion compensates rolled-back grant revocation. Audit records retain result-only account evidence.

Source-bound communication drafts are independent from the existing relationship draft workspace; they never copy encrypted snippets into its unencrypted text fields. Gmail restricted-scope operator verification and isolated project setup are deployment prerequisites.
