# Conversational concierge implementation and acceptance matrix

Status: local implementation is reviewable; the complete goal remains open for the shared/family privacy decision and live-model acceptance. “Local acceptance checks pass” means deterministic application and domain checks, not live-provider validation or publication.

Pre-delivery regression: **2,685 examples, 0 failures**, **96.92% line** and **81.32% branch** coverage in `/tmp/carecierge-provider-integration-full-rspec.log` and `/tmp/carecierge-provider-integration-full-process.log`. Ruby lint passed on the three Ruby files changed in the provider-testing increment; the earlier full lint baseline passed **1,209 files**. JavaScript lint, JS/CSS builds, Brakeman (zero warnings/errors), Bun audit and Bundler Audit passed before these backend-only increments. Memory validated **72 claims**, **3 graphs**, **19 indexes** and synced **1,200 relations**. Coverage found **193 watched changes covered, none uncovered**; audit passed with **0 errors and 80 warnings**, including source overlaps, historical verification metadata and an existing expired waiver. This run includes simulated provider integration and malformed-response recovery, local provider configuration, source-index migration, work-mode extensions, related-source lifecycle corrections and checklist follow-up references. No GitHub signoff is claimed.

## Goal and design contract

The default authenticated landing is a working relationship concierge. Natural-language requests operate on the same records as People, Today, reminders, plans, and shared spaces. Existing screens remain available. English is default and Spanish has equivalent capabilities.

The user's supplied brief confirms the existing Carecierge visual direction: white/stone surfaces, restrained moss actions, system typography, familiar controls, and persistent shared navigation. The Impeccable craft composition is a readable conversation with a prominent bottom composer, an inline current-person selector, useful starters, resumable history, source references, and action receipts. On wider screens history/context can sit beside the conversation; mobile uses deliberate disclosure and a keyboard-safe composer. No raster artwork is required. Errors, ambiguity, approval, streaming, empty and interrupted states are first-class states.

## Architecture and ordering

1. Establish encrypted owner-scoped conversation, turn and action persistence; durable request identities; policy and deletion boundaries. Write failing tests before implementation.
2. Adapt the RubyLLM Rails chat scaffold to application-owned presentation and a bounded provider runner. Persist action outcomes independently from generated prose; tool adapters call domain operations, not controllers.
3. Implement the entire matrix in coherent groups, extracting controller-owned domain operations only where sharing is necessary. Add deterministic tests of real records and side effects.
4. Build the responsive EN/ES workspace, inline decisions and correction flows, context/source controls, navigation and authentication redirects.
5. Integrate export/deletion, privacy invalidation, metadata-only instrumentation and recovery. Review authorization and retry behavior.
6. Run focused checks, full repository validation, bilingual browser journeys, source and UI review, memory validation/sync/audit. Record actual evidence below before marking rows complete.

## Capability matrix

All tool inputs are allowlisted and owner-scoped. Every execution rechecks policy, active state, feature gates, consent and any selected sensitive context. Destructive requests require an explicit decision bound to the stored action arguments and current record version. An explicit permitted low-risk request can execute immediately. Inferred memories remain proposals.

| ID | Workflow and required conversational actions | Existing operations / authority | Acceptance evidence required | Status |
| --- | --- | --- | --- | --- |
| C01 | Find, create, update and archive people; choose among ambiguous names | RelationshipProfile, RelationshipProfilePolicy, AuditEvents::Track | Real profile CRUD, archive confirmation, foreign/archived denial, ambiguity choices | Local acceptance checks pass |
| C02 | Save, recall, search, correct, review and delete memories | MemoryRecord, MemoryRevision, RelationshipMemorySearch, profile/vault locks | Saved explicit memory, source-backed recall, correction revision and trust reset, deletion approval, protected exclusions | Local acceptance checks pass |
| C03 | Record/edit/delete interactions, recaps, moods and manual timeline entries; request/retry extraction | Existing record policies, recap timeline and Interaction sync, MemoryExtractionJob | Source side effects, extraction feature flag/enqueue/execution, system-entry protection | Local acceptance checks pass |
| C04 | Review, approve, reject or correct extracted memory proposals | MemoryExtractions::Review, ApprovalQueue, ApprovalDecisions | Pending proposals are not facts, exact reviewed content, replay rejection/idempotency, canonical memory | Local acceptance checks pass |
| C05 | Manage preferences, notes, important dates and contact rhythms | Profile nested-attribute rules, RelationshipPreference, ImportantDate, ContactCadence | Same-profile nested IDs, enum validation, protected notes, cadence and date rules | Local acceptance checks pass |
| C06 | Manage commitments, promises, desires and goals; complete/cancel/reopen/fulfill | Commitments::Save, desires and fulfillment operations | Correct lifecycle and timeline side effects, follow-up references | Local acceptance checks pass |
| C07 | Create/edit/remove reminders; snooze/complete; attach to supported relationship sources | Reminder domain operations and authorization, automation decisions | Owner-local scheduling, ambiguous time clarification, permission decisions, same-source rules | Local acceptance checks pass |
| C08 | Create/update/archive/complete/reopen event plans; create/update/delete/complete/reopen tasks | EventPlans::Create/Update, EventPlan/PlanTask policies and lifecycles | Birthday/anniversary source provenance, follow-up context, budgets, template preservation, reminder linkage | Local acceptance checks pass |
| C09 | Generate/review/promote backups; manage personal-touch checklists/items | BackupPlans::Generate/Promote, existing checklist operations | Source-fenced generation, exact promotion approval, preservation of existing tasks, item transitions | Local acceptance checks pass |
| C10 | Manage supported manual vendor, shortlist, quote and booking records | Existing vendor/booking services and policies | Manual-record receipts, optimistic locks, plan/timeline synchronization, no external execution claim | Local acceptance checks pass |
| C11 | Generate/read/save/dismiss briefings; generate/edit/restore/delete message drafts | Existing briefing and message-draft services | Mode/context fences, consent, immutable revisions, source references, no sending | Local acceptance checks pass |
| C12 | Generate/alternate/save/dismiss gift recommendations; gift history and supported gift planning/bundles | Existing gift recommendation, gift, purchase-plan and gift-box operations | Permission and source gates, budget/currency handling, manual purchase status, given outcome | Local acceptance checks pass |
| C13 | Read and act on daily priorities, suggestions and pending approvals | DailyFeed::ForUser, Today::Overview, Suggestions, ApprovalQueue | Truthful source/time labels, source-owned transitions, dismissal/snooze, explicit review decisions | Local acceptance checks pass |
| C14 | Applicable shared/family items and professional relationship workflows | Shared-space membership/item policies, ProfessionalContext and generation fences | Membership revocation, item visibility, own versus shared context, selected work-only provider context | Pending shared/family decision |
| C15 | Resumable bilingual chat with person context, inline references/receipts/clarifications/decisions | Owner-scoped conversation policy; RubyLLM scaffold adapted to Rails/Turbo | Real tool-backed EN/ES journeys, refresh/resume, readable streaming and recovery, keyboard/mobile/screen-reader checks | Deterministic checks pass; live model pending |
| C16 | Default authenticated landing after login/onboarding; intended destinations and all manual screens | Devise redirects, Welcome, Onboarding, shared shell | Sign-in/sign-up/onboarding/stored destination tests, locale preservation, persistent navigation | Local acceptance checks pass |
| C17 | Durable deduplication, bounded provider work and truthful recovery | Conversation/turn/action execution state and transaction boundaries | Duplicate submission/job/tool action, crashed run, stale approval, bounded loops/context/usage, provider failure | Local acceptance checks pass |
| C18 | Secure history, live authorization and data lifecycle | Owner export/deletion, vault/mode/source invalidation, log filters | Cross-owner request/stream/job denial, revoked source exclusion, account/AI/relationship deletion, export redaction | Local acceptance checks pass |

## Existing external boundaries and necessary handoffs

Chat may prepare and record the app's supported manual steps. Sending messages, contacting providers, making purchases/payments, executing bookings, and granting sharing authority retain their existing manual boundaries. OAuth connection and vault reauthentication use the established authenticated flow. These handoffs must be explicit and must not replace internal actions that can safely be completed in chat.

## Required end-to-end journeys

- J01: “Remember that Ana prefers quiet restaurants.” Verify a real memory and its existing profile rendering.
- J02: “What did Ana tell me about her new job?” Verify grounded recall with actual source links, uncertainty, and a truthful no-result case.
- J03: “Start planning Ana's birthday next month.” Then “Keep it small and add a reminder a week before.” Clarify only missing consequential details; verify plan, tasks and reminder in existing screens.
- J04: “I promised to call Dad on Friday. Remind me.” Verify commitment and authorized owner-local reminder without duplicates.
- J05: “What should I follow up on this week?” Verify source-backed current priorities and an inline action.
- J06: Run equivalent Spanish journeys and correct a saved detail inline; preserve the revision and shared UI consistency.

## Context and verification authority

Context retrieved using `bin/memory sync` and `bin/memory context --task 'Implement full RubyLLM relationship concierge chat with owner-scoped tools and post-login landing'`.

Relevant systems: `authentication`, `relationship_profiles`, `event_plans`, `automation_permissions`, `daily_feed`, `agent_workflow`, plus shared relationship/data lifecycle systems retrieved as each adapter is implemented.

Relevant claims: `authentication.user_access_flow`, `authentication.account_access_boundary`, `authentication.localization_baseline`, `automation_permissions.permission_decisions`, `relationship_profiles.ai_memory_extraction`, `relationship_profiles.professional_mode_uses_only_explicitly_selected_work_context`, `relationship_profiles.message_drafts_are_private_review_only_and_revisioned`, `relationship_profiles.briefings_are_source_backed_private_and_user_controlled`, `daily_feed.concierge_queue_is_derived_and_owner_scoped`, `event_plans.plans_are_owner_scoped_source_backed_and_user_controlled`, and `agent_workflow.local_ci_signoff_gate`. Retrieved event-plan claims marked needs_verification require code/test confirmation.

Current source-review findings and unresolved review scope are saved in [concierge-review.md](concierge-review.md).

[Deterministic provider integration](concierge-provider-testing.md) exercises J01–J06
with scripted provider HTTP responses through the real RubyLLM parser and tools on
both transports and in both locales. These tests verify execution given specific
model responses; they do not establish live natural-language tool selection.

Verification commands: focused `bundle exec rspec` per capability, full `bundle exec rspec`, `bin/rubocop`, `bun run lint:js`, application asset builds, repository `bin/ci` under its local signoff rules, `bin/memory validate`, `bin/memory sync`, `bin/memory coverage --git-diff`, and `bin/memory audit --git-diff` for canonical memory changes. Do not report GitHub delivery or signoff without actual publication authority and matching evidence.


## Acceptance evidence map

Service spec names below are under `spec/services/concierge/`; browser suites are under `spec/system/`. All listed suites run in the full RSpec gate. Existing domain tests complement chat adapters by asserting the same canonical lifecycles.

| Criterion | Evidence |
| --- | --- |
| C01 | `people_spec`, `clarification_spec`; bilingual person-choice browser journeys |
| C02 | `execute_spec`, `record_version_spec`, `memory_proposals_spec`; bilingual memory/correction journeys |
| C03 | `profile_records_spec`, existing recap/mood/interaction/timeline domain and request specs |
| C04 | `memory_proposals_spec`, `approvals_spec`, `planning_spec`; existing extraction/review/job specs |
| C05 | `profile_records_spec`, `search_spec`, `professional_scope_spec`; existing preference/date/note/cadence specs |
| C06 | `profile_records_spec`, `concierge_journeys_spec`; existing commitment/desire lifecycle specs |
| C07 | `planning_spec`, `gifts_spec`, `professional_scope_spec`; owner-local browser journeys and reminder domain specs |
| C08 | `planning_spec`, `plan_ideas_spec`; birthday follow-up browser journey and plan/task domain specs |
| C09 | `occasions_spec`, `search_spec`; backup/checklist domain and request specs |
| C10 | `vendors_spec`; manual receipt request tests and vendor/comparison/quote/booking domain specs |
| C11 | `generated_actions_spec`, `professional_scope_spec`; Spanish approval/job browser journey and generation domain specs |
| C12 | `gifts_spec`, `professional_scope_spec`; gift/purchase/box domain specs |
| C13 | `priorities_spec`, `ideas_spec`, `approvals_spec`; bilingual follow-through journey and suggestion/review domain specs |
| C14 | Professional: `configure_context_spec`, `professional_scope_spec`, gift/vendor/occasion suites and bilingual editor journey. Shared/family: pending privacy decision |
| C15 | `concierge_spec`, `concierge_journeys_spec`, request/history/retry suites; live-model interpretation pending acceptance with the selected local model |
| C16 | Onboarding requests, `user_access_flow_spec`, concierge requests; existing destination/authentication specs |
| C17 | `submit_spec`, `execute_spec`, `respond_spec`, `retry_spec`, generated/job/agent suites |
| C18 | `data_lifecycle_spec`, `record_version_spec`, `history_spec`, protected generation/export/request/job/log-filter suites |

## Implementation and review evidence

The encrypted owner workspace uses individually named RubyLLM operation tools with exact schemas. A fixed selector loads up to two of the 34 capability families on demand, keeping core people lookup and memory actions available. Fixed domain operations preserve revisions, side effects, ownership, feature flags and current automation decisions. Request keys, worker tokens, action fingerprints and explicit execution order prevent duplicate internal changes. Exact inline decisions bind destructive or approval-required actions; jobs carry IDs, recheck authority and commit generated results with their receipt.

History is bounded and carries typed references. Canonical fingerprints cover rich text, nested items and derived interaction text; UTC normalization preserves equivalent instants. Fixed domain associations retire only previously referenced side effects changed by the requested operation, so completing a plan or correcting a recap can continue without ignoring unrelated stale data. The focused lifecycle/vendor/gift/occasion group passed **53 examples** after reproducing six defects. The final history/request/browser group passed **33 examples**, including checklist/date identifiers needed for follow-up correction.

Professional mode has explicit owner-facing mode and source controls inside chat. A changed selection starts an empty conversation and invalidates older captured context. Ten bounded source categories support work notes, preferences, commitments, dates, gifts, plans, reminders, gift boxes, vendors and comparisons. New permitted records select only themselves. Source-derived tasks/touches require selected work evidence; gift preparation requires explicit suitability. Manual quotes require selected vendors and plans. Work booking receipts omit personal timeline entries. Work touch prompts focus on agendas, messages and practical next steps. Private and vault records remain excluded from work generation.

J01–J06 have deterministic bilingual browser coverage that calls real tools and checks actual records in existing screens. Tests cover ambiguity choices, exact reminder times, inline decisions, memory correction/revision, mobile composition, keyboard starter use and focus, source links, busy/recovery markup and resumed conversation identity. These tests do not establish live natural-language interpretation or assistive-device compatibility beyond the browser checks.

Custom source searches return bounded continuation pages, including encrypted local matching, revisions, checklists, proposals and manual records. UI history and transcript pagination are independent and retained during polling. Accessible status announcements accompany incremental text; raw payloads and provider settings stay outside the ordinary interface. Receipts offer source links and correction prompts for supported editable records.

Account/profile exports and account/AI/relationship deletion include conversations. Ordinary exports redact protected content. A fresh authorized sensitive export wraps persisted turns and generated origins without renewing their stored vault leases. Erasing a relationship removes mixed conversations known to reference that person; delayed jobs cannot recreate erased records. Logging and instrumentation retain operational metadata only.

## Generator and migration review

The installed RubyLLM **1.16.0** `ruby_llm:chat_ui` generator was invoked with `chat:ConciergeConversation`, `message:ConciergeTurn` and Tailwind templates. Its output is retained locally under `/tmp/ruby-llm-concierge-scaffold/generated`. The application adapts its conversation/form, message presentation, response job and Turbo update structure to encrypted owner-scoped records, ID-only jobs, verified receipts and authenticated polling. Generic generated model browsing, controllers/routes and broadcasting callbacks are absent from the adapted application.

The four migrations add UUID concierge tables, fenced action execution, explicit per-turn ordering and GIN-indexed hashes of typed generated output IDs. The encrypted outcome, owner, immutable authorization and source checks remain authoritative after index lookup. The source-index backfill uses an isolated encrypted migration model and has rollback/backfill tests. These migrations take normal DDL write locks; populated installations should schedule the backfills and indexes as migration work. Unrelated development/cache schema drift from dumping was removed from the diff.

## Remaining completion requirements

1. **Shared/family privacy decision:** `shared_spaces.couple_spaces_require_explicit_consent_and_isolate_private_records` currently keeps shared content out of AI context. The pending choice is explicit shared-space selection with mandatory review for published changes, or continued AI isolation with chat handoffs. No shared-content provider path or published shared write exists while that decision is pending. Implement and verify the selected boundary before C14 is complete.
2. **Live-provider acceptance:** development defaults to native Ollama, with OpenAI retained for production. Gemma 4 E2B QAT is installed as `carecierge-dev` and completed real synthetic memory saves in both language probes. Broader journeys still failed recap recall, planning, reminders or correction, including model claims without actual writes. Qwen3 1.7B was also unreliable. J01–J06 remain open until repeatable full journeys pass against the selected model, with source-backed answers and actual persisted outcomes. See [local setup](local-ai.md) and [observed results](concierge-review.md). Never put credentials in test artifacts or chat.

The local implementation evidence above predates publication. The user subsequently authorized commit, push and the PR review cycle; delivery and current-commit signoff are tracked in the pull request. `bin/ci` requires a clean pushed commit. This review cycle leaves the PR open and does not authorize merge or deployment.

## Local-provider verification

Development defaults to Ollama and production to OpenAI, with user-supplied credentials deferred. `ai.ai_providers_follow_environment_defaults_behind_application_owned_configuration` records the provider boundary. Context was refreshed with `bin/memory sync` and `bin/memory context --task` for the environment/provider change, plus changed-file context for the shared AI client and capability selector. Backend changes followed observed red/green tests. The pre-delivery complete regression passed 2,685 examples (96.92% line, 81.32% branch), including the local reasoning parameter and simulated provider integration. Changed Ruby files pass lint. These checks do not establish live-model journey acceptance.

Delivery review tightened generated-content reuse: old public labels do not override current source privacy, new briefing/gift origins retain all bounded input-source IDs, and draft origins carry a canonical context fingerprint. Legacy generated drafts without verifiable input provenance must be regenerated before chat reuse; source-free authored revisions remain available.

Privacy compatibility limitation: legacy AI event tasks and generated backups without complete generation provenance require regeneration for chat reuse. Existing conventional screens remain available. New conversational outputs retain all-input source and consent checks, including promoted backup tasks.
