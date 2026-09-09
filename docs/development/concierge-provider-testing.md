# Deterministic concierge provider integration

Test direct tool behavior and the full provider protocol independently from model
quality. Existing tool and domain specs exercise validation, authorization and
records. Existing browser journeys script `Concierge::Agent` and exercise the UI.

The additional request suite replaces only the provider HTTP transport with
scripted JSON (Ollama) or fragmented SSE (OpenAI). It retains the real controller,
queued job, RubyLLM request serialization, response parsing, capability loading,
tool dispatch, domain operations, receipts and persistence. It uses synthetic
credentials and an in-memory Faraday adapter; no model server or cloud is needed.

Acceptance checks for this testing change:

- Exercise real memory save/correction, recap recall, birthday planning and linked
  reminders, commitments and priorities in English and Spanish on both transports.
- Verify source IDs and actual saved outcomes, tool schemas on subsequent requests,
  incremental streaming, usage totals and repeated-delivery behavior.
- Exercise invalid arguments, foreign records, required approvals and provider
  failures without allowing an unauthorized write or replaying a completed write.
- Fail when the response script is exhausted or required exchanges are not consumed.
  Advance controlled timestamps between turns so follow-up order is deterministic.

The initial checks passed in 36 request examples: six core journeys in both languages
on both transports, plus six rejection/reliability cases on each transport. The
existing 11 agent/tool examples also pass. Fake responses choose explicit tool
calls, then assert the actual returned source IDs, domain outcomes and receipts.
The provider helper treats tool results as text; RubyLLM 1.16 serializes Hash tool
results as Ruby text, so the fake must not assume JSON or evaluate that text.

The tests reproduced an uncaught `JSON::ParserError` for malformed arguments in
both transports. The concierge now maps that exception to its existing recoverable
provider failure. Red evidence: `/tmp/carecierge-provider-integration-errors-red.log`.
Green evidence: `/tmp/carecierge-provider-integration-green.log` (47 examples), with
Ruby lint in `/tmp/carecierge-provider-integration-lint.log`.

The pre-delivery full suite passed 2,685 examples with 96.92% line and 81.32% branch
coverage. Evidence: `/tmp/carecierge-provider-integration-full-rspec.log` and
`/tmp/carecierge-provider-integration-full-process.log`. Memory validation and
coverage pass with 193 watched changes covered; audit reports zero errors and
80 existing warnings. No live model or cloud request was used for this test work.

Context: `bin/memory sync`, `bin/memory context --task 'Test concierge tools and real
RubyLLM tool execution with deterministic simulated provider responses'`, and
changed-file context for existing concierge agent/tool/request specs.

Relevant systems and claims: `concierge.owner_scoped_conversation_actions` and
`ai.ai_providers_follow_environment_defaults_behind_application_owned_configuration`.

Verification:

```sh
bundle exec rspec spec/agents/concierge spec/requests/concierge_provider_integration_spec.rb
bundle exec rspec
```

Focused examples can pass while the process exits nonzero for the repository's
whole-project SimpleCov thresholds. The full suite is the coverage authority.

These checks establish application behavior given specific model responses. Live
model evaluations remain separate evidence of selecting the right tools and
producing grounded answers from ordinary requests.

Delivery review adds four native-provider cases covering inherited source revocation during generation and across multiple tool-free follow-ups, transcript rendering, exports, and subsequent provider requests. Current-commit full-suite and review evidence is recorded in the pull request.

Tools advertise null only for explicitly clearable update fields. A null clears that field; omission leaves it unchanged. Required identifiers, state enums and domain-default fields such as desire capture date cannot be cleared with null. The real-tool regression suite covers date, timestamp and amount clears plus omitted-field preservation.
