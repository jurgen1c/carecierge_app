# Conversational concierge review

Status: local source and acceptance review completed for personal/professional controls, with the pre-delivery regression passing. Shared/family and live-provider acceptance remain open. This is local implementation evidence, not a delivery signoff. The full scope remains in [the capability matrix](concierge-capabilities.md).

## Reviewed boundaries

- `Concierge::Execute`, `Decide` and `ProviderExecution` resolve fixed operations under owner/profile/target locks, validate current permissions and sources, and persist confirmed domain outcomes independently of model prose. Provider calls occur outside application locks; final callbacks commit generated records and receipts together.
- `Context`, `History`, `GeneratedSources`, `Sources` and `OccasionSources` check current ownership, selected context, mode, source content and lifecycle. Initial context now records the chosen person's mode and work selection before any tool runs.
- `ConfigureContext` uses the existing professional editor, validates an exact profile version under the owner/profile locks, and opens an empty conversation after a change. Earlier messages retain their original context. The browser exercises the real editor in English and Spanish, including STI form scoping.
- Work gift preparation, bundles, vendor comparisons, quotes, manual bookings and occasion touches now have focused acceptance tests. Selected vendors are owner records; other selected categories belong to the relationship. Gift suitability remains explicit. Work touch prompts use only selected preferences.
- Work records are explicitly selected. New permitted work records add only themselves to the relevant bounded category and prune unavailable old references. Plans/reminders authorize conversational control; their contents and related records are not automatically added to ordinary generation context. Source-derived tasks require current selected work evidence.
- `ExportTurn` overlays a fresh export lease on the real persisted turn and generated origins. It does not update stored leases or detach action associations. Ordinary export remains redacted; revoked vault items remain unavailable after reauthentication.
- Custom lookup adapters return bounded continuation pages. Draft revision order, checklist order and existing quote/booking order remain adapter-controlled. Model arguments cannot specify ordering, associations or arbitrary database predicates.
- Generated origins use a GIN index over hashes of typed output IDs. The lookup narrows candidate rows before encrypted outcomes are read; owner scope, exact stored consent and current source checks still establish authority. The migration backfills encrypted historical outcomes and reverses cleanly. Its normal DDL transaction holds writes while backfilling this newly introduced concierge table; schedule it as migration work for a populated installation.

## Defects reproduced and resolved during implementation

| Finding | Resolution and evidence |
| --- | --- |
| Completed review receipts opened an unrelated pending review | Map terminal statuses to the completed queue and preserve the exact request ID; browser regression includes another pending review |
| Preference, note and cadence receipts targeted nonexistent fragments | Map to existing DOM IDs and explicit profile sections; browser tests wait for navigation and verify visible source destinations |
| A different read replaced a stale source while earlier tool text remained in model history | Revalidate existing dependencies before every new action; native multi-tool Ollama/OpenAI regressions prevent the next provider request |
| Approval availability inverted owner/profile locking for vendor-option removal | Keep the owner lock across availability checks; a committed-transaction SQL regression verifies owner-before-profile ordering |
| Completing a suggestion's source left its successful response blocked | Revalidate and retire affected suggestion references after authorized mutations; unrelated external changes still invalidate history |
| Reopening the vault did not restore history after old execution leases expired | Use current-session read contexts for transcript and generated receipts, preserving persisted leases and approval authority; revoked selections stay hidden |
| Expired polling sessions redirected sign-in to a transcript-only response | Normalize stored polling destinations to the conversation HTML route; EN/ES request regressions complete sign-in and render the workspace |
| Token-truncated replies were marked complete | Inspect provider termination metadata before non-streaming return and streaming chunk accumulation; preserve saved receipts and offer retry on interruption |
| The selected person vanished beyond the first 100 choices | Include the authorized active current selection alongside the bounded initial list on new and existing conversations |
| Post-persistence permission rejection left generation actions running after rollback | Reload the action under owner and row locks before failure recovery; a committed-transaction regression verifies terminal failure and discarded output/audit |
| Correcting inputs left inherited drafts, briefings and gift ideas blocking regeneration | Revalidate and retire affected generated references in the correction outcome, with real follow-up regeneration tests |
| History reused memories after their expiry date | Include owner-local staleness in memory fingerprints; midnight expiry removes old answers while explicit stale reads remain labeled |
| Shared task ancestors were rechecked exponentially | Memoize task results for one verification traversal while retaining cycle/depth checks and fresh subsequent checks |
| Successful input edits left stale generated task/backup references | Recheck and retire already-referenced generated outputs after authorized mutations |
| Impossible datetime dates silently normalized to another day | Validate the ISO calendar date before timestamp parsing; valid leap dates remain accepted |
| Prior-plan checks discarded source fingerprints | Compare complete identifiers against freshly authorized prior-plan inputs |
| AI tasks reused sensitive inputs omitted from model citations | Persist complete source/task/plan/consent provenance and verify it for task and backup reuse, including promoted tasks |
| Repeated searches erased revoked dependencies while RubyLLM retained earlier tool text | Recheck history before overwriting an existing read action; native Ollama/OpenAI regressions prove no next request occurs |
| Shared generation accepted truncated Anthropic and Gemini text | Validate provider-native completion indicators before returning text or structured output |
| UTC rendering dropped valid owner-local event suggestions | Rebuild suggestions in the owner time zone for reads, history and approval preconditions; owner-local expiry still applies |
| Private-context titles survived note protection in the vault | Check first-turn context availability for all history titles |
| Consent choices beyond the first 20 records were unreachable | Paginate choices with retained draft/selections, owner/vault rechecks, EN/ES labels and keyboard focus |
| Expected extraction jobs invalidated unchanged recap responses | Separate extraction progress from content fingerprints while retaining full extraction preconditions for destructive approvals |
| Different worker/request calendar dates hid valid generated drafts | Rebuild draft and generation source provenance in canonical English and the owner time zone |
| Malformed memory expiry strings silently cleared deadlines | Require ISO dates, retaining explicit null only for deliberate clearing |
| Work cadence exposed personal interaction timestamps | Omit personal aggregates from professional cadence receipts and fingerprints |
| Delegating profile handlers omitted required person IDs | Declare explicit scope requirements, preserving global reminders/reviews and plan-derived task scope |
| Switching language invalidated unchanged suggestion approvals | Check availability, consent preconditions and execution in the originating turn locale |
| Work backup receipts exposed task-linked reminders outside selected context | Require current authorized reminder ownership and work selection before generation output, search, read, preview or promotion |
| Backup promotion left read reminder fingerprints stale | Retire reviewed reminder IDs alongside replaced tasks in the same confirmed outcome |
| Correcting a memory left high-impact review receipts stale | Capture the memory-to-review dependency, including inherited references, and retire changed approvals |
| A concierge provider override inherited an incompatible event model | Inherit event-model overrides only for the matching provider; actual RubyLLM chat construction regression |
| Task-operation reconstruction dropped nullable-field metadata | Preserve declared nullability when adding the event-plan scope; task deadline/detail clear regression |
| Deleting private notes erased the provenance restriction on their turn | Retain immutable private-context IDs separately from current selected/authored notes; selected and authored deletion regressions exclude unrestricted follow-up reuse |
| Generated briefings and gifts reused corrected or deleted input facts | Resolve supported source IDs against current owner records and compare canonical fingerprints for every generation input, including uncited inputs |
| Explicit null updates reported success without clearing nullable fields | Per-adapter clearable-field declarations drive nullable tool schemas and preserve explicit null through persistence; omitted fields remain unchanged and unsupported nulls are rejected |
| Relationship exports omitted inherited people from turn scope | Include inherited source profile IDs, keeping mixed-person follow-ups out of single-relationship exports |
| Extracted-memory review left its recap and review-request references stale | Capture reverse recap and approval dependencies in both review adapters and retire changed references |
| Expanded mobile context clipped later controls | Let the bounded mobile desk scroll; native browser wheel regression reaches the final private-note checkbox and send control, with mobile work-editor coverage |
| Protected first-message text remained visible in conversation titles | Store a generic title for new vault-selected conversations and guard legacy titles using the first turn; batch first-turn lookup keeps history bounded |
| Draft-deletion approval ignored newly saved same-settings revisions | Include immutable revision IDs in the workspace precondition; stale deletion is rejected before any content is removed |
| High-impact memory review offered an unsupported edit | Reject correction arguments for unsupported review types during precondition validation, before creating or applying confirmation |
| A stored worker vault lease let another signed-in browser render protected chat and approve its actions | Require the requesting browser session to be unlocked for protected transcript rendering, approval and retry; locked/unlocked HTML, polling and mutation regressions |
| Quote deletion changed previously read reminder links | Capture vendor-quote reminder dependencies and retire references changed by nullification |
| Cadence receipts omitted their derived latest-interaction timestamp | Fingerprint the live aggregate, render that same value, and retire cadence dependencies after authorized chat mutations |
| Deleting a generating conversation removed uncited-input provenance and reopened generated reads | Write-once origin-required flags survive chat deletion; absent origins fail closed, with reversible encrypted-outcome backfill tests |
| Checklist reorder left a read sibling receipt stale | Retire the changed sibling reference while returning the moved item; reorder history regression |
| Draft deletion left read revision references stale | Capture draft revision dependencies and retire deleted references in the confirmed outcome |
| Priority cards silently omitted message drafts | Resolve draft cards through the current authorized revision while retaining the original feed key; dismiss and snooze regressions |
| Non-streaming RubyLLM ran before_message after sending the request | Application-owned ProviderChat guards the actual provider boundary; native transports assert zero HTTP calls on rejected initial context and no extra call after oversized or revoked tool results |
| Professional turns could access an unselected global reminder by ID | Reject global reminder IDs in work context; read, update, complete, snooze and destroy regressions |
| Local approvals checked the target but omitted other sources read by the turn | Revalidate history for availability and approval execution; revoked-note/stable-commitment regression |
| Newly authored private-note authority could escape into later generated reads | Include authored-note authority in generated provenance and require matching origin consent; later-turn draft regression |
| Generated content treated old public categories as permanent permission | Revalidate cited public-note/memory visibility; retain all new briefing/gift input IDs and draft context fingerprints; private, vaulted and uncited-input regressions |
| Follow-up regeneration did not retire outputs inherited through history | Include inherited output IDs when computing superseded records; real briefing regeneration regression |
| Polling preserved container focus but dropped focused controls | Stable focus keys on receipt links, approvals, corrections, choices and retries; browser tests preserve focused links and correction controls |
| Work-context creation invalidated earlier profile lookup receipts, including delegated reminder creation | Refresh the changed profile reference in the same operation result; work and nested gift-box follow-through tests |
| Private-note creation and correction invalidated their own context | Advance only authorized note versions, retain newly authored private access for the current turn, clear authorized removed selections, and reject unrelated edits; scoped/general note and bounds tests |
| Keyword search omitted derived interaction text | Search preloaded `display_notes` through bounded local search; recap, mood and manual interaction regression |
| Tool-free follow-ups lost inherited source dependencies | Persist bounded transitive history sources and observed profiles before provider submission; both native transports test revocation during generation and across rendering, exports and later prompts |
| A stalled final worker attempt permanently blocked its conversation | Terminalize exhausted expired turns and invalidate their tokens under locks before a new submission; live/retryable workers remain exclusive |
| Polling replaced the transcript and reset readers to the top | Preserve the latest scroll offset and transcript keyboard focus immediately before replacement; browser regression |
| Malformed provider tool-call JSON escaped recovery and left the turn running | Normalize `JSON::ParserError` to the existing provider failure; both real RubyLLM transports covered with simulated HTTP responses |
| The installed RubyLLM chat rejected integer tool concurrency | Use `concurrency: false`; a regression constructs the actual installed chat without network access |
| The full tool catalog exceeded the local context; multi-action wrappers were unreliable in local probes | Discover fixed capability families on demand and expose individual operation schemas; selector validation and actual domain-tool tests |
| Unselected relationship tools advertised an optional person ID even though their base resolver required one | Require looked-up IDs in those provider schemas while preserving optional global/derived scope; native tool regressions |
| An empty provider response completed a blank turn | Fail visibly while retaining any saved receipts; empty-response regression |
| Older generated features still required OpenAI keys in development | Route native provider generation before cloud credential checks; local draft, briefing, gift, extraction and social-text tests with no cloud request |
| Equivalent timestamps in different zones invalidated source receipts and approvals | UTC canonical fingerprints; record-version and bilingual journey tests |
| Optional metadata could replace a receipt's computed title or source identity | Reserved receipt fields; important-date request test |
| Expired generated-source origins prevented reauthenticated sensitive export | Export-only wrappers retaining real associations; export/generated/domain group passed 74 examples |
| Fixed lookup limits hid older records | Continuation pages; search/occasion group passed 17 examples, including restoration from an older revision page |
| Work selection could change before the first tool without invalidating a queued request | Snapshot initial professional context; configure-context test |
| STI form scope omitted the selected relationship mode | Explicit relationship-profile form scope; both browser locales |
| Invalid birthday text silently became an empty date; professional creation made a personal profile | Strict ISO-date input and inherited work mode; people group passed three examples |
| A generated work gift was saved outside selected work records | Atomic save/selection, work-gift suitability checks and refreshed idea context; professional/browser group passed 36 examples |
| An old task's nonsensitive personal source remained readable after selecting its plan for work | Require selected work evidence for source-derived tasks; professional-scope test |
| Deleted selected records prevented later work-record creation | Prune unavailable selections before validating a new selected record; regression included in the current full run |
| Reading generated content decrypted unrelated action history and could fail on an unrelated damaged payload | Indexed exact-origin lookup; generated/export/migration group passed 28 examples, including encrypted backfill and rollback |
| Plan/task completion made its own reminder receipts stale; recap edits/deletion left old derived references | Fixed domain associations retire only changed, previously referenced side effects; focused group passed 53 examples |
| A derived interaction fingerprint did not include the recap/mood text it displayed | Fingerprint displayed text; same-timestamp source-change regression |
| A work reminder could link an unselected vendor quote | Resolve selected work vendor before persistence; regression |
| Follow-up references omitted a personal touch's required checklist/date identifiers | Carry authorized parent identifiers; history/request/browser group passed 33 examples |

## Open review items

1. Shared/family chat control depends on the pending owner decision about transmitting explicitly selected shared content. No shared-content provider path or published shared write is implemented while that decision is pending.
2. Local Ollama is configured with `carecierge-dev`, built from `gemma4:e2b-it-qat`. The model runs on the tested 4 GB GPU with CPU/RAM offload and completed real synthetic memory saves in English and Spanish probes. Broader live journeys remain unreliable: saved recap recall failed, and the model sometimes claimed a reminder or correction without a corresponding tool action. Qwen3 1.7B was also unreliable. Deterministic real-tool browser tests prove application behavior, not live natural-language interpretation or truthful model prose. Receipts remain the authority for actual writes.

The pre-provider-change local verification passed 2,625 examples with 96.86% line and 80.98% branch coverage, plus Ruby/JavaScript lint, builds and vulnerability checks. Brakeman reports zero warnings/errors. Memory coverage has no uncovered watched changes; audit has zero errors and 79 documented warnings. See the capability matrix for commands and evidence paths. Those implementation checks predate publication; delivery and current-commit signoff are tracked in the pull request.

Pre-delivery regression including simulated-provider integration: full `bundle exec rspec` passed 2,685 examples with 96.92% line and 81.32% branch coverage. Evidence: `/tmp/carecierge-provider-integration-full-rspec.log` and `/tmp/carecierge-provider-integration-full-process.log`. Ruby lint passes on the three Ruby files changed in this testing increment (`/tmp/carecierge-provider-integration-lint.log`); the earlier full lint baseline passed 1,209 files. The final memory audit reports zero errors and 80 warnings, with all 193 watched changes covered. One previously recorded waiver is now expired; it was not extended as part of this work.

Live evidence: `/tmp/carecierge-gemma-selected.log`, `/tmp/carecierge-gemma-general.log` and `/tmp/carecierge-gemma-reasoning-live.log` record successful real memory writes; `/tmp/carecierge-gemma-reasoning-journeys.log` records failed broader journeys with the application prompt and low reasoning. A separate structured tool-preselection experiment added latency and enabled a priorities lookup but did not resolve the central failures; that extra provider request was removed. Its output is `/tmp/carecierge-gemma-selected-tools-journeys.log`. Live scripts used synthetic test owners inside rolled-back transactions. Their process exit status alone is not acceptance: inspect persisted action receipts and the reported acceptance booleans. The frozen-time harness also gives multiple turns equal creation times, so its follow-up ordering is not evidence of correct chronology; use advancing controlled time in future multi-turn acceptance runs.

The [provider integration suite](concierge-provider-testing.md) initially added 36 deterministic
examples with simulated Ollama JSON and fragmented OpenAI SSE. It retains actual
RubyLLM parsing and tool dispatch, unlike the existing browser-level scripted agent.
It covers the core bilingual journeys, scope/argument rejection, approvals,
streaming persistence, deduplication and recovery without a live model dependency.

Legacy generated drafts without verifiable input provenance require regeneration before chat reuse. Source-free authored revisions remain available. Existing manual screens remain available; this limitation is a privacy boundary, not a provider outage.

The origin-required migration adds a constant-default boolean to three generated-record tables and backfills existing chat outputs from encrypted successful actions. No index is needed for the point-read flag. The migration is reversible; its transaction holds DDL locks while backfilling, so schedule it for populated installations. Flags contain no conversation text and remain until the generated record itself is deleted.

Legacy AI event tasks and generated backups without complete generation provenance require regeneration before conversational reuse. Existing conventional screens retain their domain behavior. New task and backup origins capture every supplied input; deleting their origin conversation closes chat reuse. Preparation and persistence remain under the domain locking/transaction boundaries.
