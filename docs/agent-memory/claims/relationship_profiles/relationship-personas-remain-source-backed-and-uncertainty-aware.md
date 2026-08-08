---
id: relationship_profiles.relationship_personas_remain_source_backed_and_uncertainty_aware
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Relationship personas remain source-backed and uncertainty-aware

claim: >
  RelationshipPersona deterministically builds an owner-scoped, evidence-backed
  summary from structured relationship preferences and current memory records.
  Stale, review-needed, and archived memories are excluded, while protected
  memories stay out of rendered traits. Explicitly confirmed preferences, user-confirmed or
  user-corrected memories, and non-AI memories with confirmed confidence render
  as confirmed; every other trait keeps localized non-absolute language and an
  inferred label. Traits link back to their source
  evidence and existing correction flow, and semantic title or body corrections
  become user-confirmed context. Memory mutations refresh the persona through
  Turbo. Suggestion inputs preserve certainty, evidence, and source identity,
  fail closed for archived profiles, and decrypt protected memory payloads only
  after the item's explicit suggestion consent is allowed.

source_files:
  - app/models/relationship_persona.rb
  - app/models/privacy_vault_item.rb
  - app/controllers/relationship_profiles_controller.rb
  - app/controllers/memory_records_controller.rb
  - app/views/relationship_personas/_section.html.erb
  - app/views/components/persona_trait_component.rb
  - app/views/components/persona_trait_component.html.erb
  - app/views/memory_records/refresh.turbo_stream.erb

related_files:
  - app/models/memory_record.rb
  - app/models/relationship_preference.rb
  - app/services/privacy_vault/payload.rb
  - app/views/relationship_profiles/_form.html.erb
  - app/views/relationship_profiles/show.html.erb
  - config/locales/en.yml
  - config/locales/es.yml
  - spec/models/relationship_persona_spec.rb
  - spec/components/persona_trait_component_spec.rb
  - spec/requests/relationship_personas_spec.rb
  - spec/requests/memory_records_spec.rb
symbols:
  - RelationshipPersona
  - RelationshipPersona::Trait
  - PersonaTraitComponent
routes:
  - relationship_profile
  - edit_relationship_profile
  - edit_relationship_profile_memory_record
tags:
  - relationship_profiles
  - relationship_persona
  - suggestion_inputs
  - uncertainty
  - source_evidence

verification:
  - bundle exec rspec spec/models/relationship_persona_spec.rb spec/components/persona_trait_component_spec.rb spec/requests/relationship_personas_spec.rb spec/requests/memory_records_spec.rb spec/requests/relationship_profiles_spec.rb
  - bin/rubocop app/models/relationship_persona.rb app/controllers/relationship_profiles_controller.rb app/views/components/persona_trait_component.rb spec/models/relationship_persona_spec.rb spec/components/persona_trait_component_spec.rb spec/requests/relationship_personas_spec.rb
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/ci

last_verified_commit: null
---

# Relationship personas remain source-backed and uncertainty-aware

## Claim

Relationship personas are deterministic views over existing relationship
context rather than a second AI or persistence pipeline. Structured preferences
and current memory records provide each trait's statement, detail, evidence,
confidence, and correction target.

Explicitly confirmed preferences, user-confirmed/user-corrected memories, and
non-AI memories whose confidence has been confirmed establish confirmed traits.
All other context remains visibly cautious, and AI-inferred memory stays
inferred regardless of confidence. A semantic title or body edit marks memory as
user-corrected; only a body edit creates a body-revision row. Stale,
review-needed, and archived memories do not enter the persona. Vault-protected
memory never enters rendered traits, while suggestion inputs may decrypt its
payload only when the vault item is explicitly allowed for suggestions. Archived
relationships expose no suggestion inputs.

The persona's suggestion-input interface returns the rendered statement,
detail, certainty, evidence, source type, and source UUID. This prepares CAR-49
without generating suggestions or presenting inferred traits as truth.

## Why It Matters

Personas summarize sensitive relationship context and will influence later
recommendations. Preserving owner scope, vault exclusions, evidence, correction
paths, and uncertainty prevents a convenient summary from bypassing the trust
boundaries established by relationship memory and AI review.

## Evidence

- `app/models/relationship_persona.rb`
- `app/models/privacy_vault_item.rb`
- `app/controllers/memory_records_controller.rb`
- `app/views/components/persona_trait_component.html.erb`
- `app/views/relationship_personas/_section.html.erb`
- `app/views/memory_records/refresh.turbo_stream.erb`
- `spec/models/relationship_persona_spec.rb`
- `spec/requests/memory_records_spec.rb`
- `spec/requests/relationship_personas_spec.rb`

## Verification

- `bundle exec rspec spec/models/relationship_persona_spec.rb spec/components/persona_trait_component_spec.rb spec/requests/relationship_personas_spec.rb spec/requests/memory_records_spec.rb spec/requests/relationship_profiles_spec.rb`
- `bin/rubocop app/models/relationship_persona.rb app/controllers/relationship_profiles_controller.rb app/views/components/persona_trait_component.rb spec/models/relationship_persona_spec.rb spec/components/persona_trait_component_spec.rb spec/requests/relationship_personas_spec.rb`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/ci`
