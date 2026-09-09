---
id: concierge.owner_scoped_conversation_actions
type: constraint
system: concierge
status: current
confidence: high
severity: critical

title: Conversational actions use encrypted owner-scoped state and domain authority

claim: >
  Concierge conversations, turns, and action payloads are encrypted and owner scoped.
  Browser request keys, claimed worker tokens, and per-turn action fingerprints prevent
  duplicate execution. An explicit per-turn execution order resolves timestamp ties.
  Canonical content fingerprints cover source bodies, selected rich text, and exact
  approval targets so same-timestamp edits cannot reuse obsolete consent or facts.
  Fingerprints normalize timestamps to UTC so provider and browser time zones do not
  invalidate unchanged records. Receipt metadata cannot replace core source identity,
  version, title, or body. Authorized encrypted and rich-text search scans bounded
  pages locally; ordinary column searches retain Ransack filtering. Custom lookups
  also return explicit continuation pages, including draft revisions, saved briefings,
  proposal queues, manual quotes/bookings, backup options and personal touches.
  Adapter-owned ordering preserves revision history and checklist position.
  Initial context captures the selected person's mode and work selection before
  the first tool, fencing queued requests when that context changes.
  Newly created people inherit a professional conversation's mode; personal birthday
  input is unavailable in work actions, and ordinary birthdays require valid ISO dates.
  Profile and plan generation fences are excluded from ordinary fact fingerprints;
  operations such as backup promotion separately bind their required generation version.
  Fixed RubyLLM operation adapters validate allowed fields and
  invoke existing domain services and policies under owner, profile, and target locks.
  Decisions are separate authenticated requests bound to exact arguments, target versions,
  current permission, and expiry; model text cannot approve them. Provider tools are
  individually named and expose each operation's exact field schema and validator.
  Operations using the base relationship resolver require a looked-up relationship
  UUID in the provider schema when the conversation has no selected person. Explicit
  global and record-derived resolvers keep their existing optional scope semantics.
  Core people lookup and memory tools start enabled; a fixed capability selector loads up to two
  additional groups at a time without establishing authority or mutating domain data.
  RubyLLM tool execution uses concurrency false, the installed gem's serial mode.
  Empty provider responses fail the turn instead of completing a blank reply.
  Malformed provider tool-argument JSON becomes a recoverable provider-unavailable
  turn failure before those arguments reach a domain tool. Deterministic provider
  integration tests replace only HTTP responses, retaining real RubyLLM JSON/SSE
  parsing, capability loading, authorization, queued execution and domain receipts.
  The runner totals all response-token usage and bounds context, elapsed time and loops.
  Full owner-facing decision previews are retained in the encrypted ledger but omitted
  from repeated provider payloads. Explicitly retired source IDs distinguish an
  operation's own replacement from an unrelated concurrent source change. Fixed domain
  associations identify already referenced side effects before a mutation; only
  related references actually changed or removed by that operation are retired.
  This preserves follow-through after plan/task completion and recap correction or
  deletion without ignoring unrelated stale sources. Derived interaction fingerprints
  include the displayed recap or mood text. Context and source
  checks exclude revoked relationships, changed modes, unselected professional records,
  unselected private notes, protected records, and obsolete generated answers. Retry
  preserves completed actions and cannot run beside another active conversation turn.
  Authorized note changes advance only their own selected-source versions; making
  a note public or approving its deletion removes that selection. Newly authored
  private notes receive bounded, versioned access for that turn, including when no
  person is selected; future turns require fresh selection. Work-context extension
  records a refreshed profile source alongside the operation result, including
  delegated operations such as gift-box reminders. Interaction keyword searches
  use displayed source text through bounded local search, with sources preloaded.
  Provider failures never establish application success; persisted receipts are authority.
  Generated operations claim a separately fenced action, release application locks for
  network work, and commit their outcome in the domain generator persistence transaction.
  Approved generation uses an ID-only job; explicit retries are bounded and recheck
  authority, source context and the original approval. Drafts and briefings consume only
  exact turn-selected private and allowed vault items, and sensitive generated content
  requires a matching currently authorized chat origin before it is reused.
  That origin retains an immutable authorization fingerprint, including selected
  work-record content versions; changes to a turn cannot relabel an older generated
  result with fresh consent. Public-note and memory provenance is rechecked against
  current private/vault visibility, rather than trusting old sensitivity labels.
  New briefings and gift ideas retain all bounded generation input IDs in their
  encrypted origin receipt, including uncited inputs. Draft origins retain a
  canonical bounded-context fingerprint; generated drafts lacking verifiable input
  provenance require regeneration before chat reuse. Source-free authored drafts
  remain readable. Generated-output retirement includes inherited history references
  so follow-up regeneration can supersede its prior output atomically.
  Generated origins are found through a GIN-indexed array of opaque hashes of typed
  output IDs. The encrypted outcome remains authoritative: ownership, immutable
  authorization and current source checks follow the lookup. Unrelated action
  payloads are not decrypted to find a matching origin. The additive migration
  backfills existing encrypted outcomes with an isolated migration model and is reversible.
  Bounded follow-up history includes current typed record references so later requests
  can resolve earlier actions without inventing IDs; obsolete references and replies
  are excluded together. Before provider submission, the exact bounded history persists
  its transitive source dependencies and observed profile snapshots in encrypted turn
  context. These inherited sources participate in generation, rendering, export and
  later-history revalidation even when a follow-up calls no tools. Dependency growth
  fails at 200 sources or 100 observed profiles rather than dropping authority checks.
  A new submission terminalizes an expired final-attempt turn and clears its worker
  token before checking availability, retaining completed action receipts.
  Inline person choices contain only authorized saved lookup results. Choosing a
  person resumes the latest unanswered read-only request once, using fresh context
  with no inherited private-note or vault selection; requests that already mutated
  a record cannot be replayed through this control.

source_files:
  - app/services/concierge/read_turn.rb
  - app/services/concierge/export_turn.rb
  - app/controllers/concerns/privacy_vault_session.rb
  - app/services/concierge/task_sources.rb
  - app/services/event_plans/suggest.rb
  - app/services/event_plans/context_builder.rb
  - app/services/backup_plans/generate.rb
  - app/services/backup_plans/promote.rb
  - app/views/components/concierge_context_options_component.rb
  - app/views/components/concierge_context_options_component.html.erb
  - app/views/concierge_conversations/context_page.html.erb
  - spec/requests/concierge_source_boundaries_spec.rb
  - db/migrate/20260909045534_add_concierge_origin_required_to_generated_records.rb
  - spec/migrations/add_concierge_origin_required_spec.rb
  - spec/requests/concierge_provider_integration_spec.rb
  - spec/support/concierge_provider_responses.rb
  - docs/development/concierge-provider-testing.md
  - spec/agents/concierge/agent_spec.rb
  - app/tools/concierge/capabilities_tool.rb
  - spec/agents/concierge/capabilities_tool_spec.rb
  - app/services/concierge/related_sources.rb
  - db/migrate/20260908180644_add_source_keys_to_concierge_actions.rb
  - app/services/concierge/configure_context.rb
  - app/controllers/concierge_contexts_controller.rb
  - app/services/concierge/operations/manual_plan_records.rb
  - app/services/concierge/operations/proposals.rb
  - app/services/concierge/clarify.rb
  - app/controllers/concierge_clarifications_controller.rb
  - app/services/concierge/operations/people.rb
  - app/services/concierge/search_records.rb
  - app/services/concierge/operations/base.rb
  - app/services/concierge/operations/profile_records.rb
  - app/services/concierge/operations/tasks.rb
  - app/services/concierge/operations/plan_ideas.rb
  - app/services/concierge/professional_scope.rb
  - app/services/concierge/operations/work.rb
  - app/services/concierge/record_version.rb
  - app/services/concierge/gift_sources.rb
  - db/migrate/20260908153929_add_execution_order_to_concierge_actions.rb
  - app/services/concierge/vendor_sources.rb
  - spec/agents/concierge/tool_spec.rb
  - app/services/concierge/operations/backups.rb
  - app/services/concierge/operations/touches.rb
  - app/services/concierge/occasion_sources.rb
  - app/services/concierge/provider_execution.rb
  - app/services/concierge/generated_sources.rb
  - app/services/concierge/operations/generated.rb
  - app/services/concierge/operations/drafts.rb
  - app/services/concierge/operations/briefings.rb
  - app/jobs/concierge_action_job.rb
  - db/migrate/20260908145455_add_execution_state_to_concierge_actions.rb
  - app/services/concierge/execute.rb
  - app/services/concierge/decide.rb
  - app/services/concierge/submit.rb
  - app/services/concierge/retry.rb
  - app/services/concierge/context.rb
  - app/services/concierge/history.rb
  - app/services/concierge/sources.rb
  - app/services/concierge/catalog.rb
  - app/services/concierge/operation.rb
  - app/agents/concierge/agent.rb
  - app/agents/concierge/provider_chat.rb
  - app/tools/concierge/tool.rb
  - app/models/concierge_conversation.rb
  - app/models/concierge_turn.rb
  - app/models/concierge_action.rb
  - app/policies/concierge_conversation_policy.rb
  - app/jobs/concierge_response_job.rb
  - config/initializers/filter_parameter_logging.rb
  - db/migrate/20260908132443_create_concierge_workspace.rb
  - db/schema.rb

related_files:
  - spec/services/concierge/planning_spec.rb
  - spec/services/concierge/profile_records_spec.rb
  - spec/migrations/add_concierge_source_keys_spec.rb
  - spec/services/concierge/people_spec.rb
  - spec/services/concierge/configure_context_spec.rb
  - spec/requests/concierge_contexts_spec.rb
  - spec/services/concierge/clarification_spec.rb
  - spec/services/concierge/search_spec.rb
  - spec/services/concierge/plan_ideas_spec.rb
  - spec/system/concierge_journeys_spec.rb
  - spec/services/concierge/professional_scope_spec.rb
  - spec/services/concierge/record_version_spec.rb
  - spec/services/concierge/gifts_spec.rb
  - spec/services/concierge/generated_actions_spec.rb
  - docs/development/concierge-capabilities.md
  - spec/services/concierge/execute_spec.rb
  - spec/services/concierge/history_spec.rb
  - spec/services/concierge/retry_spec.rb
  - spec/requests/concierge_spec.rb

symbols:
  - Concierge::ConfigureContext
  - Concierge::ProviderExecution
  - ConciergeActionJob
  - Concierge::Execute
  - Concierge::Decide
  - Concierge::Context
  - Concierge::History
  - Concierge::Agent

routes:
  - concierge_conversation_concierge_clarifications
  - concierge_conversations
  - transcript_concierge_conversation
  - concierge_conversation_concierge_turns
  - concierge_conversation_concierge_action

tags:
  - concierge
  - constraint

verification:
  - bundle exec rspec spec/agents/concierge spec/requests/concierge_provider_integration_spec.rb
  - bundle exec rspec spec/services/concierge/planning_spec.rb spec/services/concierge/profile_records_spec.rb spec/services/concierge/record_version_spec.rb
  - bundle exec rspec spec/services/concierge/generated_actions_spec.rb spec/services/message_drafts spec/services/relationship_briefings spec/services/professional_context_spec.rb
  - bundle exec rspec spec/services/concierge spec/models/concierge_conversation_spec.rb spec/models/concierge_turn_spec.rb spec/jobs/concierge_response_job_spec.rb spec/agents/concierge spec/requests/concierge_spec.rb
  - bundle exec rspec spec/system/concierge_spec.rb spec/config/concierge_parameter_logging_spec.rb

last_verified_commit: null
---

# Conversational actions use encrypted owner-scoped state and domain authority

## Claim

Chat uses the same persisted relationship records as the conventional workspaces. Tool
arguments identify requested data; they never establish the user, ownership, permission,
feature availability, or sensitive-context consent.

## Constraint

Keep server-side permission and source checks at every execution and decision boundary.
Do not run provider requests under database mutation locks. The RubyLLM adapter disables
payload instrumentation and overrides the tool method that otherwise logs arguments.
Only local, supported records may change; external contacts, messages, bookings, purchases,
payments, and sharing authority retain their established manual boundaries.

The implementation capability matrix remains the scope and acceptance authority. This
claim describes the implemented execution boundary; it does not assert that every requested
conversational workflow or live-provider journey is complete.

## Why It Matters

Retries, tool output, and generated prose must not create a second authority path or replay
private content after its source has changed.

## Verification

- Run the focused commands above, then the full repository suite and delivery gate before
  claiming overall completion. The focused suite alone does not satisfy SimpleCov.

Concierge::ProviderChat checks the live execution lease, context, source history and request budgets before the shared RubyLLM provider boundary, including non-streaming Ollama. The native HTTP integration suite verifies that rejected requests never reach the transport.

Local approvals revalidate the turn source history before applying a confirmed mutation. Professional turns cannot read or mutate global reminders by ID. Generated output provenance includes newly authored private-note authority so later turns cannot reuse it without matching consent.

Generated drafts, briefings and gift ideas created through chat retain a write-once concierge_origin_required flag on the domain output. Deleting its conversation never clears that flag: without a surviving authorized origin the output is unavailable to chat. Existing successful origins are backfilled reversibly; boolean metadata contains no prompt or source content. Verify with bundle exec rspec spec/migrations/add_concierge_origin_required_spec.rb spec/services/concierge/generated_actions_spec.rb. Checklist reorders retire changed sibling references; draft workspace deletion retires its referenced revisions. Priority draft cards resolve through authorized current revisions while keeping their feed item keys.

A stored vault lease authorizes background execution only. Protected chat rendering, inline action decisions and retries additionally require an active vault lease in the current browser session. Locked sessions receive no protected turn content or receipts. Verify with bundle exec rspec spec/requests/concierge_source_boundaries_spec.rb. Personal contact cadence fingerprints include the live latest-interaction aggregate; authorized chat mutations retire changed aggregate references. Quote deletion similarly retires references to reminders changed by foreign-key nullification.

Vault-selected first messages receive nonsensitive conversation titles. Legacy protected titles use the same current-session and context checks as their first turn; first turns are fetched in one bounded history-page query. Draft workspace versions include their immutable revision IDs so an earlier deletion approval cannot delete newly saved revisions. Only extracted-memory review requests accept correction arguments; unsupported high-impact edits fail before confirmation. Verification: bundle exec rspec spec/requests/concierge_source_boundaries_spec.rb spec/services/concierge/generated_actions_spec.rb spec/services/concierge/approvals_spec.rb.

Relationship export and erasure scope includes inherited history source profile IDs, even when a lookup did not explicitly observe that profile. Extracted-memory decisions capture reverse recap and approval-request dependencies so successful reviews retire only changed references. The mobile chat desk scrolls when expanded private or work context exceeds its available height. Verification: bundle exec rspec spec/services/concierge/data_lifecycle_spec.rb spec/services/concierge/approvals_spec.rb spec/system/concierge_spec.rb.

Private-context provenance is immutable across authorized note deletion or privacy changes: private_context_ids retains selected and newly authored private-note IDs separately from mutable execution selections. History compatibility and generated-output authorization consult that provenance. Briefing/gift origins store canonical input-source fingerprints and revalidate them before reuse; supported personal source IDs must still resolve to authorized live records. Operation schemas declare null only for adapter-owned CLEARABLE_FIELDS on update/save operations, and validation preserves explicit null while distinguishing omission. Domain-default fields are not advertised as clearable. Verify with bundle exec rspec spec/services/concierge/profile_records_spec.rb spec/services/concierge/generated_actions_spec.rb spec/services/concierge/gifts_spec.rb spec/requests/concierge_provider_integration_spec.rb.

Memory-record mutations capture dependent approval requests, including inherited review receipts. Task-operation reconstruction preserves nullable-field declarations. Verify with bundle exec rspec spec/services/concierge/approvals_spec.rb spec/services/concierge/planning_spec.rb.

Backup option visibility validates every reviewed reminder against the current owner and event plan; professional reminders must also be explicitly selected. The check applies to generation receipts, lookup, preview and promotion. Promotion retires reviewed reminder source references alongside replaced tasks so its own completion/detachment does not invalidate the turn. Verify with bundle exec rspec spec/services/concierge/occasions_spec.rb spec/services/concierge/professional_scope_spec.rb spec/services/backup_plans.

Professional cadence receipts and fingerprints exclude personal interaction timestamps. Tools declare their required relationship scope explicitly; delegating profile handlers still require a looked-up person when none is selected, while global reminders/reviews and plan-derived tasks retain optional person scope. Inline approval availability and execution use the originating turn locale, restoring the request locale afterward. Verify with bundle exec rspec spec/agents/concierge/tool_spec.rb spec/services/concierge/professional_scope_spec.rb spec/services/concierge/ideas_spec.rb.

Recap source fingerprints exclude extraction lifecycle metadata so normal extraction jobs preserve unchanged content. Recap mutation preconditions additionally fingerprint extraction metadata and proposal IDs, preserving stale-consent checks. Generated context fingerprints rebuild in canonical English and the owner time zone, including request/render/export checks. Memory expiry arguments require ISO dates; explicit nullable updates remain the only way to clear a deadline. Verify with bundle exec rspec spec/services/concierge/profile_records_spec.rb spec/services/concierge/generated_actions_spec.rb spec/services/concierge/execute_spec.rb spec/jobs/memory_extraction_job_spec.rb.

Conversation history titles follow first-turn context availability for every sensitive-context origin, including private notes later protected in the vault. Private-note and allowed-vault consent selectors paginate in stable creation order with 20 records per page; Turbo frame continuation retains draft text and selected checkboxes and moves focus to the new page. Full-page navigation retains the selected relationship. Frame requests recheck owner scope, professional-mode exclusion and current vault unlock; the existing six-per-category submission cap remains authoritative. Verify with bundle exec rspec spec/requests/concierge_source_boundaries_spec.rb spec/system/concierge_spec.rb.

SuggestionSources rebuilds date-sensitive ideas in the owner time zone at the shared lookup boundary, including source revalidation and approval preconditions. Originating-locale checks remain in place, and both thread locale and time zone are restored afterward. Verify with bundle exec rspec spec/services/concierge/ideas_spec.rb spec/services/concierge/history_spec.rb.

Repeated read actions recheck current source history before replacing their saved result. RubyLLM retains prior tool messages, so refreshing an action row must never erase a revoked dependency that guards retained provider content. First-time read actions retain their existing source records; changed repeated results require a fresh authorized turn when history is stale. Verify with bundle exec rspec spec/services/concierge/execute_spec.rb spec/requests/concierge_provider_integration_spec.rb; both native provider fixtures assert that no further HTTP request follows revocation.

TaskSources requires an indexed, encrypted action origin for AI task and backup reuse. Generation captures all supplied source fingerprints, existing-task input versions, plan fields, originating locale and explicit consent; citations alone never establish full input authority. Optional domain preparation callbacks execute under existing owner/profile/plan locks, and task filters exclude unavailable prior or current AI tasks from provider inputs. Task input versions ignore completion/supersession timestamps and lock counters so promotion preserves valid content dependencies; source content, ownership and consent still revalidate. Prior-plan source identifiers are compared in full against freshly authorized context, including supported locales. Recursion is bounded to twelve task dependencies. Legacy AI tasks/backups lacking complete origins require regeneration for chat; deleting the origin conversation makes their derived outputs unavailable. Verify with bundle exec rspec spec/services/concierge/plan_ideas_spec.rb spec/services/concierge/occasions_spec.rb spec/services/event_plans spec/services/backup_plans.

Task provenance verification memoizes shared task results only within the current traversal, after cycle/depth checks; each new authorization check starts fresh. Authorized mutations recheck already-referenced task/backup outputs for the same profile and retire those whose full input provenance changed, preserving the newly saved receipt. Datetime tool arguments validate their calendar-date portion strictly before Time.iso8601 so invalid dates cannot normalize silently. Verify with bundle exec rspec spec/services/concierge/plan_ideas_spec.rb spec/services/concierge/occasions_spec.rb spec/services/concierge/execute_spec.rb.

Authorized input corrections also recheck and retire affected inherited draft, briefing and gift-recommendation references, permitting follow-up regeneration without retaining obsolete output authority. Memory fingerprints include staleness evaluated on the owner's calendar date; crossing expiry invalidates earlier answers while explicitly reread stale records retain their labeled status. Verify with bundle exec rspec spec/services/concierge/history_spec.rb spec/services/concierge/generated_actions_spec.rb spec/services/concierge/gifts_spec.rb.

Provider failure recovery reloads the action under its owner and row locks before checking the persisted execution token. A rejected post-persistence verification rolls back generated records and audit events, then records terminal action failure immediately; rolled-back in-memory attributes cannot prevent acquiring the recovery lock. Verify with the committed-transaction context in bundle exec rspec spec/services/concierge/generated_actions_spec.rb.

ProviderChat requires a successful termination status and rejects incomplete statuses before non-streaming return and before streamed chunks are accumulated or tool calls execute. A stream ending without terminal metadata also fails. Streaming validation extends only the current provider instance because RubyLLM drops termination metadata from accumulated messages. Interrupted replies follow retryable provider failure while retaining completed action receipts. The workspace keeps an authorized active selected person available even beyond the first 100 relationship choices. Verify with bundle exec rspec spec/requests/concierge_provider_integration_spec.rb spec/requests/concierge_source_boundaries_spec.rb.

Authorized source mutations retire affected suggestion references after rechecking their current evidence, while unrelated changes still invalidate history. Reauthenticated protected-history rendering uses ReadTurn with the current browser vault lease for context, response and receipt-source checks, including generated origins. ExportTurn shares this read context. Stored execution leases, pending approvals and retries remain unchanged; revoked or changed selected items remain unavailable. Verify with bundle exec rspec spec/services/concierge/ideas_spec.rb spec/requests/concierge_source_boundaries_spec.rb spec/services/concierge/data_lifecycle_spec.rb.

Every newly executed action revalidates existing history, including first-time reads with a different operation or fingerprint, so one lookup cannot conceal a changed dependency retained in earlier provider tool text. Approval availability holds the owner lock across context and target checks, preserving the owner-before-profile order used by execution and vendor-option removal. Verify with bundle exec rspec spec/requests/concierge_provider_integration_spec.rb spec/services/concierge/vendors_spec.rb; the transport fixture preserves fragmented multiple tool calls, and the lock regression observes committed transaction boundaries.

Receipt navigation sends terminal review states to the completed queue with the exact request ID; pending and deferred states keep their corresponding queues. Preference receipts target the existing persona-source DOM ID, cadence receipts open the contact-rhythm section, and relationship-note receipts open About where the notes are rendered. Verify actual link navigation and visible destinations with bundle exec rspec spec/system/concierge_spec.rb.
