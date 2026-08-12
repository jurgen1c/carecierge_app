---
id: relationship_profiles.message_drafts_are_private_review_only_and_revisioned
type: constraint
system: relationship_profiles
status: current
confidence: high
severity: critical

title: Message drafts are private, review-only, and revisioned

claim: >
  Each active, owner-scoped relationship profile has at most one draft workspace whose
  generated, edited, and restored text is retained as immutable revisions; saved
  edits also persist the selected message type and tone. The workspace consumes
  the shared semantic primary and danger palette. The
  synchronous OpenAI Responses request uses store false, aggregates all ordered
  output-text parts, and uses bounded, JSON-serialized
  untrusted context: current non-protected profile facts and visible structured relationship
  fields, dates, uncertainty-marked preferences,
  public notes, and uncertainty-marked reviewed memories are eligible by default; private notes require
  explicit per-generation selection, and vault context additionally requires
  an active password-backed vault lease revalidated under the account lock while
  context reads serialize with vault mutations under the profile lock. Profile rendering bounds newest-first
  revision history to pages of ten while the editor remains on the current
  revision. The feature records metadata-only
  audit evidence, participates in data export and cascading deletion, and has
  no send, recipient, delivery, scheduling, or external-action path.

source_files:
  - app/models/message_draft.rb
  - app/models/draft_revision.rb
  - app/models/relationship_field_value.rb
  - app/services/message_drafts/context_builder.rb
  - app/services/message_drafts/generate.rb
  - app/services/message_drafts/open_ai_generator.rb
  - app/services/message_drafts/vault_access_error.rb
  - app/services/privacy_vault/lease.rb
  - app/controllers/concerns/privacy_vault_session.rb
  - app/controllers/message_drafts_controller.rb
  - app/views/components/message_draft_workspace_component.rb
  - app/views/components/message_draft_workspace_component.html.erb
  - app/serializers/data_exports/snapshot.rb
  - config/initializers/filter_parameter_logging.rb
  - config/deploy.yml

related_files:
  - app/controllers/relationship_profiles_controller.rb
  - app/policies/message_draft_policy.rb
  - config/routes.rb
  - config/locales/message_drafts.en.yml
  - config/locales/message_drafts.es.yml
  - db/migrate/20260811111116_create_message_drafts.rb
  - db/migrate/20260811111117_add_message_draft_generation_version_to_relationship_profiles.rb
  - docs/features/04-04-message-drafting-assistant.md
  - spec/services/message_drafts/context_builder_spec.rb
  - spec/services/message_drafts/open_ai_generator_spec.rb
  - spec/services/message_drafts/generate_spec.rb
  - spec/requests/message_drafts_spec.rb
  - spec/config/filter_parameter_logging_spec.rb
  - spec/config/ai_memory_deploy_spec.rb
  - spec/system/message_drafts_spec.rb

symbols:
  - MessageDraft
  - DraftRevision
  - MessageDrafts::ContextBuilder
  - MessageDrafts::Generate
  - MessageDrafts::OpenAiGenerator
  - PrivacyVault::Lease
  - MessageDraftsController
  - MessageDraftWorkspaceComponent

routes:
  - generate_relationship_profile_message_draft
  - relationship_profile_message_draft
  - restore_revision_relationship_profile_message_draft

tags:
  - relationship_profiles
  - message_drafting
  - privacy
  - ai
  - immutable_revisions
  - constraint

verification:
  - bundle exec rspec spec/models/message_draft_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts spec/policies/message_draft_policy_spec.rb spec/components/message_draft_workspace_component_spec.rb spec/requests/message_drafts_spec.rb spec/requests/data_controls_spec.rb spec/system/message_drafts_spec.rb
  - bin/rubocop app/models/message_draft.rb app/models/draft_revision.rb app/services/message_drafts app/controllers/message_drafts_controller.rb app/controllers/relationship_profiles_controller.rb app/policies/message_draft_policy.rb app/views/components/message_draft_workspace_component.rb spec/models/message_draft_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts spec/policies/message_draft_policy_spec.rb spec/components/message_draft_workspace_component_spec.rb spec/requests/message_drafts_spec.rb spec/system/message_drafts_spec.rb
  - bun run build:css
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/ci

last_verified_commit: null
---

# Message drafts are private, review-only, and revisioned

## Claim

Message drafting is an owner-scoped, review-only workspace. One profile can
have one `MessageDraft`, while every generation, saved edit, and restore appends
a new `DraftRevision`. A saved edit persists the type and tone selected in the
shared drafting form along with its new revision. Earlier revision rows cannot
be updated. The reusable workspace styles use the documented semantic primary
and danger tokens instead of raw color utilities.

## Constraint

Ordinary generation is limited to current non-protected relationship context.
Visible structured relationship fields are eligible profile context; hidden and
vault-protected field values remain excluded.
Preference confidence and available source notes, plus memory confidence and
source, remain visible to the provider; inferred, low-confidence, and AI-inferred
facts are explicitly tentative. The provider input is JSON-serialized so relationship
context remains a data value even when it contains prompt-like delimiters.
Private notes cross the boundary only after explicit selection for that request;
vault data also requires the service to revalidate the controller-touched lease's
owner, password fingerprint, revocation version, and inactivity deadline under
the account lock immediately before decryption. Context assembly
holds the same profile lock used by vault protection, so a completed protection
cannot leave previously loaded plaintext eligible for the provider. Context has both an overall bound and
a complete label-and-value per-entry bound, with the first eligible explicitly selected sensitive entry
from each category prioritized ahead of ordinary long-form sources so access
and audit evidence remain aligned. Date-stale memories are excluded before the
per-category limit is applied, and long labels are bounded separately so they
cannot displace confidence and source metadata. The request locale explicitly selects English or
Spanish output. Context is prompt-injection resistant, the Responses request
disables provider storage, aggregates all ordered output-text parts, and allows
only completed well-formed responses to become revisions; incomplete, malformed, TLS-failed, and protocol-failed responses
follow the localized provider-error path. Audit metadata never includes the
draft or source content, and submitted edits are
filtered from parameter logs. Archived profile pages omit the workspace, and
generation, edit, and restore recheck active state under the profile lock before
appending a revision. Deleting a draft advances a profile-scoped generation
version so provider responses from older in-flight requests cannot recreate the
workspace. No route or operation can send the result.
The profile page loads immutable history newest-first in bounded pages of ten;
the editor continues to show the current revision on every history page.

## Why It Matters

Personal messages and relationship history are sensitive. This boundary keeps
AI use inspectable and user-initiated, preserves useful revisions without
silent rewriting, and prevents a future agent from casually converting a draft
feature into communication automation or broadening its data access.

## Verification

- `bundle exec rspec spec/models/message_draft_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts spec/policies/message_draft_policy_spec.rb spec/components/message_draft_workspace_component_spec.rb spec/requests/message_drafts_spec.rb spec/requests/data_controls_spec.rb spec/system/message_drafts_spec.rb`
- `bin/rubocop app/models/message_draft.rb app/models/draft_revision.rb app/services/message_drafts app/controllers/message_drafts_controller.rb app/controllers/relationship_profiles_controller.rb app/policies/message_draft_policy.rb app/views/components/message_draft_workspace_component.rb spec/models/message_draft_spec.rb spec/models/draft_revision_spec.rb spec/services/message_drafts spec/policies/message_draft_policy_spec.rb spec/components/message_draft_workspace_component_spec.rb spec/requests/message_drafts_spec.rb spec/system/message_drafts_spec.rb`
- `bun run build:css`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/ci`
- `bundle exec rspec spec/config/ai_memory_deploy_spec.rb`
