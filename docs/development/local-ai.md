# Local AI development

Development defaults to Ollama; production and deterministic tests default to
OpenAI. These defaults apply to the concierge and its generated drafts, briefings,
gift ideas, memory extraction, social context, event suggestions and backups.
The app does not switch to a cloud provider when local generation fails.

## Setup

With Ollama installed and running:

```sh
ollama pull gemma4:e2b-it-qat
ollama create carecierge-dev -f config/ollama/Modelfile
ollama run carecierge-dev --think=false "Hello"
bin/dev
```

The model alias uses the quantized Gemma 4 E2B variant with a 32,768-token context. The warm-up
command avoids doing first-load work during the first app request. The concierge
starts with people, memories and a capability selector; it loads other fixed tool
groups as needed. Loading a group grants no additional authority.

Gemma 4 E2B QAT supports text, tools and vision. Its download is about 4.3 GB;
it can split execution across GPU and system memory on a 4 GB GPU. Model size and
actual app behavior both matter: Qwen3 1.7B passed a small lookup probe but did not
reliably perform the full memory-saving request in this checkout. Do not treat
basic connectivity or a tool-capability flag as full conversational acceptance.

On the tested GTX 1650 SUPER (4 GB GPU memory, 31 GiB system RAM), the Gemma alias
loaded with a 32,768-token context and used mixed CPU/GPU execution. Real synthetic
memory saves succeeded in English and Spanish probes. Broader journeys still
missed saved facts or claimed changes without executing tools. This is a usable
local development model, but full concierge behavior has not passed live acceptance.
The model tag and capabilities are documented in the
[Ollama model listing](https://ollama.com/library/gemma4:e2b-it-qat).

Local Ollama tool responses are currently requested without token streaming: the
installed Ollama 0.32.15 / RubyLLM 1.16.0 combination returned empty or textual tool
calls in streaming probes. The concierge enables low reasoning effort for local
tool orchestration and does not display or save the separate reasoning field.
The chat publishes the completed local response and
verified action receipts. OpenAI keeps streaming. Recheck this compatibility before
re-enabling Ollama streaming; do not execute tool-shaped text as an app command.

## Operator configuration

| Setting | Purpose |
| --- | --- |
| `CARECIERGE_AI_PROVIDER` | Shared provider override; otherwise Ollama in development, OpenAI in production/test |
| `CARECIERGE_AI_MODEL` | Shared model override for native RubyLLM calls |
| `CARECIERGE_OLLAMA_MODEL` | Local model default when no shared model is selected |
| `OLLAMA_API_BASE` | Defaults to `http://127.0.0.1:11434/v1` |
| `OLLAMA_API_KEY` | Optional authentication for an explicitly configured Ollama endpoint |
| `OPENAI_API_KEY` | Production cloud credential; encrypted Rails credentials remain supported |
| `CARECIERGE_CONCIERGE_PROVIDER`, `CARECIERGE_CONCIERGE_MODEL` | Existing concierge-specific overrides |
| `CARECIERGE_EVENT_PLAN_PROVIDER`, `CARECIERGE_EVENT_PLAN_MODEL` | Existing event and backup overrides |
| `CARECIERGE_MESSAGE_DRAFTING_MODEL`, `CARECIERGE_RELATIONSHIP_BRIEFING_MODEL`, `CARECIERGE_GIFT_RECOMMENDATION_MODEL`, `CARECIERGE_MEMORY_EXTRACTION_MODEL`, `CARECIERGE_SOCIAL_CONTEXT_MODEL` | Existing feature model overrides |

Encrypted `ai.provider` and `ai.model` credentials take precedence over the shared
environment settings. Existing feature credentials keep their previous precedence.
Use a model compatible with the selected provider. Ollama names ending in `cloud`
or other Ollama cloud aliases do not provide local execution.

User-supplied provider accounts and keys are deferred to a separate ticket. This
change introduces no account-level key storage or provider settings screen.

## Verification

```sh
bundle exec rspec spec/agents/ai spec/agents/concierge spec/agents/event_plans spec/agents/backup_plans spec/config/ollama_configuration_spec.rb
```

Deterministic tests cover environment routing, local generation without cloud keys,
non-stored production requests, failure handling and the actual installed RubyLLM
chat constructor. Full RSpec remains the coverage authority. Real local model
journeys are a separate acceptance check; see `concierge-capabilities.md` and
`concierge-review.md` for observed results and unresolved scope.
