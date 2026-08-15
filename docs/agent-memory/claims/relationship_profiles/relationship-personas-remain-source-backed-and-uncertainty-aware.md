---
id: relationship_profiles.relationship_personas_remain_source_backed_and_uncertainty_aware
type: fact
system: relationship_profiles
status: current
confidence: high
severity: important

title: Relationship personas remain source-backed and uncertainty-aware

claim: >
  RelationshipPersona builds a deterministic, owner-scoped summary from
  preferences and current memories. Stale, review-needed, archived, and
  protected memories stay out of rendered traits. Confirmed preferences and
  qualifying user or non-AI memories render as confirmed; all others remain
  non-absolute and inferred. Traits link to evidence and correction flows.
  Semantic title or body corrections become confirmed, and submitted notes
  remain in correction history even for title-only edits. Turbo refreshes the
  persona after memory mutations. Suggestion inputs preserve certainty,
  evidence, and source identity, fail closed for archived profiles, and decrypt
  protected payloads only with explicit suggestion consent. Consent-gated
  protected suggestion inputs use the eight most recently protected eligible
  memories before deterministic certainty and title ordering, including on
  preloaded aggregate surfaces.

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

Personas are deterministic views over structured preferences and current memory,
not a second AI or persistence pipeline. Confirmed preferences and qualifying
user or non-AI memories form confirmed traits; all other context remains cautious
and inferred. Traits carry evidence and correction targets.

Semantic title or body edits mark memory as user-corrected. Body edits create
revision rows; submitted notes are also preserved for title-only edits, while a
title-only edit without a note creates no empty history. Stale, review-needed,
archived, and protected memories stay out of rendered traits. Consent-gated vault
payloads may enter suggestion inputs only, and archived profiles expose none.
Protected suggestion input selection first bounds to the eight most recently
protected eligible memories, then applies the same deterministic trait ordering
for ordinary and preloaded consumers.

Suggestion inputs preserve the statement, detail, certainty, evidence, source
type, and source UUID for CAR-49 without generating suggestions or asserting
inferences as truth.

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
