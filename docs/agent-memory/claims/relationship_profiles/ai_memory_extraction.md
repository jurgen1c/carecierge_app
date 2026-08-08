---
id: relationship_profiles.ai_memory_extraction
type: fact
system: relationship_profiles
status: current
confidence: high
severity: critical

title: AI memory extraction is asynchronous, source-backed, and owner-approved

claim: >
  Feature-flagged recaps enqueue an OpenAI Responses API adapter with strict,
  non-stored structured output. Normalized source excerpts must occur in the
  recap. A data migration installs the flag disabled and makes legacy requests
  retryable; jobs reclaim interrupted processing and make requests retryable
  when rollout is disabled.
  Proposals stay separate until the owner approves, rejects, or corrects each
  one. Locked, idempotent reviews preserve AI uncertainty and corrected source.
  Exports include proposals. Selective deletion locks and cancels owned
  extraction state before removing AI data, preventing delayed recreation while
  retaining user-corrected memories.

source_files:
  - app/models/extracted_memory.rb
  - app/services/memory_extractions/open_ai_extractor.rb
  - app/services/memory_extractions/extract.rb
  - app/services/memory_extractions/review.rb
  - app/jobs/memory_extraction_job.rb
  - app/controllers/extracted_memories_controller.rb
  - app/policies/extracted_memory_policy.rb
  - app/views/extracted_memories/_section.html.erb
  - app/views/components/extracted_memory_review_component.rb
  - app/views/components/extracted_memory_review_component.html.erb
  - db/migrate/20260808040856_create_extracted_memories.rb
  - db/data/20260808060000_install_ai_memory_extraction_rollout.rb

related_files:
  - .kamal/secrets
  - app/controllers/conversation_recaps_controller.rb
  - app/models/conversation_recap.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/data_deletions/delete_ai_data.rb
  - config/deploy.yml
  - config/initializers/filter_parameter_logging.rb
  - config/locales/en.yml
  - config/locales/es.yml
  - config/routes.rb
  - spec/components/extracted_memory_review_component_spec.rb
  - spec/config/ai_memory_deploy_spec.rb
  - spec/data_migrations/install_ai_memory_extraction_rollout_spec.rb
  - spec/jobs/memory_extraction_job_spec.rb
  - spec/models/extracted_memory_spec.rb
  - spec/requests/extracted_memories_spec.rb
  - spec/services/memory_extractions/extract_spec.rb
  - spec/services/memory_extractions/open_ai_extractor_spec.rb
  - spec/services/memory_extractions/review_spec.rb
symbols:
  - ExtractedMemory
  - MemoryExtractionJob
  - MemoryExtractions::OpenAiExtractor
  - MemoryExtractions::Extract
  - MemoryExtractions::Review
  - ExtractedMemoriesController
  - ExtractedMemoryPolicy
  - ExtractedMemoryReviewComponent
routes:
  - review_relationship_profile_extracted_memory
tags:
  - ai_extraction
  - memory_approval
  - source_tracking
  - confidence
  - feature_flags
  - owner_scope

verification:
  - bundle exec rspec spec/models/extracted_memory_spec.rb spec/services/memory_extractions spec/jobs/memory_extraction_job_spec.rb spec/components/extracted_memory_review_component_spec.rb spec/requests/extracted_memories_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb
  - bin/rubocop app/controllers/extracted_memories_controller.rb app/jobs/memory_extraction_job.rb app/models/extracted_memory.rb app/services/memory_extractions spec/models/extracted_memory_spec.rb spec/services/memory_extractions spec/jobs/memory_extraction_job_spec.rb spec/requests/extracted_memories_spec.rb spec/components/extracted_memory_review_component_spec.rb
  - bundle exec rspec
  - bin/ci

last_verified_commit: null
---

# AI memory extraction is asynchronous, source-backed, and owner-approved

## Claim

AI extraction is an owner-gated proposal workflow. The background adapter uses
a strict JSON schema, disables provider storage, and persists only generic
failure codes. Its rollout flag is installed disabled, and legacy or
flag-interrupted requests become retryable. Retried jobs reclaim interrupted
processing state without duplicating persisted proposals.

Proposals retain category, original content, confidence, recap, review state,
and an excerpt that must occur in the normalized title, body, or transcript.
Approval creates an `ai_inferred` memory without upgrading confidence;
correction preserves the proposal and creates a confirmed `user_corrected`
memory; rejection creates none. Locked one-way reviews prevent duplicates.

The responsive queue keeps evidence and uncertainty next to each decision, and
recap Turbo responses refresh that queue. Correction inputs are filtered from
logs. Exports include proposal metadata.
Selective deletion locks and cancels owned extraction state before removing AI
data, so delayed results cannot recreate proposals; user-corrected memories
remain.

## Why It Matters

Relationship recaps and inferred memories may contain intimate context. Keeping
provider use explicitly feature-gated, preserving evidence and uncertainty, and
requiring an owner decision before canonical mutation prevents silent memory
changes and keeps later suggestions, reminders, and briefings explainable.

## Evidence

- `app/models/extracted_memory.rb`
- `app/services/memory_extractions/open_ai_extractor.rb`
- `app/services/memory_extractions/extract.rb`
- `app/services/memory_extractions/review.rb`
- `app/jobs/memory_extraction_job.rb`
- `app/controllers/extracted_memories_controller.rb`
- `app/views/extracted_memories/_section.html.erb`
- `app/views/components/extracted_memory_review_component.html.erb`
- `spec/services/memory_extractions/review_spec.rb`
- `spec/requests/extracted_memories_spec.rb`

## Verification

- `bundle exec rspec spec/models/extracted_memory_spec.rb spec/services/memory_extractions spec/jobs/memory_extraction_job_spec.rb spec/components/extracted_memory_review_component_spec.rb spec/requests/extracted_memories_spec.rb spec/requests/conversation_recaps_spec.rb spec/requests/data_controls_spec.rb spec/config/filter_parameter_logging_spec.rb spec/config/ai_memory_deploy_spec.rb spec/data_migrations/install_ai_memory_extraction_rollout_spec.rb`
- `bundle exec rspec`
- `bin/ci`
