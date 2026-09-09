---
id: ai.ai_providers_follow_environment_defaults_behind_application_owned_configuration
type: constraint
system: ai
status: current
confidence: high
severity: critical

title: AI providers follow environment defaults behind application-owned configuration

claim: >
  Ai::Configuration defaults development to native Ollama and production and test
  to OpenAI. Operator credentials and environment overrides select the provider;
  model defaults are paired with that provider. Local development uses the
  carecierge-dev model built from config/ollama/Modelfile, and does not require
  cloud credentials or fall back to a cloud provider after a local failure.
  Ollama tool calls use non-streaming requests and publish completed text because
  streaming probes against the installed provider returned unusable tool responses;
  OpenAI retains token streaming.
  Event/backup planning and concierge generation use RubyLLM. Existing OpenAi
  draft, briefing, gift, extraction and social-analysis entry points retain their
  production Responses transport and use Ai::TextGeneration with native RubyLLM
  for other providers. They preserve domain validation, source selection and
  manual review boundaries. Ollama responses have bounded output. Concierge tool
  orchestration enables low reasoning effort; standalone structured/text generation
  disables thinking to preserve its existing output budgets. The application persists
  the provider's answer content and token counts, not its separate reasoning field.
  Local text generation and
  concierge requests have a 90-second
  timeout with no automatic retries. Content instrumentation and stream debug
  logging are disabled in these isolated RubyLLM contexts. Native generation
  rejects empty, truncated and incorrectly shaped structured output. User-owned
  provider credentials and automatic provider failover are not implemented.
  Concierge normalizes malformed provider tool-call JSON to a recoverable turn
  failure. In-memory transport tests exercise both native Ollama JSON and OpenAI
  SSE without replacing RubyLLM's parser or tool dispatcher.

source_files:
  - spec/requests/concierge_provider_integration_spec.rb
  - spec/support/concierge_provider_responses.rb
  - app/agents/ai/configuration.rb
  - app/agents/ai/generation_error.rb
  - app/agents/ai/text_generation.rb
  - app/agents/event_plans/llm_configuration.rb
  - app/agents/concierge/agent.rb
  - app/agents/concierge/provider_chat.rb
  - config/initializers/ruby_llm.rb
  - config/ollama/Modelfile
  - app/services/message_drafts/open_ai_generator.rb
  - app/services/relationship_briefings/open_ai_generator.rb
  - app/services/gift_recommendations/open_ai_generator.rb
  - app/services/memory_extractions/open_ai_extractor.rb
  - app/services/social_context_notes/open_ai_analyzer.rb
  - spec/agents/ai/configuration_spec.rb
  - spec/agents/ai/feature_routing_spec.rb
  - spec/agents/ai/text_generation_spec.rb
  - spec/config/ollama_configuration_spec.rb
  - docs/development/local-ai.md

tags:
  - ai
  - constraint
  - ollama
  - openai
  - environment

verification:
  - bundle exec rspec spec/requests/concierge_provider_integration_spec.rb
  - bundle exec rspec spec/agents/ai spec/agents/event_plans spec/agents/backup_plans spec/agents/concierge spec/config/ollama_configuration_spec.rb
  - bundle exec rspec spec/services/message_drafts/open_ai_generator_spec.rb spec/services/relationship_briefings/open_ai_generator_spec.rb spec/services/gift_recommendations/open_ai_generator_spec.rb spec/services/memory_extractions/open_ai_extractor_spec.rb spec/services/social_context_notes/open_ai_analyzer_spec.rb

last_verified_commit: null
---

# AI provider selection

Provider choice belongs to operator configuration, outside user-facing chat and
model tool arguments. Changing provider does not authorize additional source data,
sharing, external actions, or automatic acceptance of generated content.

The existing OpenAi class names are retained for compatibility with their production
Responses clients. Local calls branch before the cloud-key check and reuse the
same instructions, source payloads, schemas and domain validators.

See `docs/development/local-ai.md` for setup and the distinction between deterministic
integration verification and live model quality checks. Small local models require
separate evidence of tool and language behavior; a model capability flag alone is
not acceptance evidence.

Concierge::ProviderChat checks the live execution lease, context, source history and request budgets before the shared RubyLLM provider boundary, including non-streaming Ollama. The native HTTP integration suite verifies that rejected requests never reach the transport.

Event model overrides are inherited only when the selected provider matches the configured event provider. A concierge-only provider override uses the selected provider's application model default unless an explicit concierge model is supplied. Verify with bundle exec rspec spec/agents/concierge/agent_spec.rb spec/agents/ai spec/agents/event_plans.

Ai::TextGeneration checks provider-native completion indicators before accepting content: OpenAI-compatible finish_reason, Anthropic stop_reason and Gemini candidate finishReason. Explicit truncation or other non-completion reasons raise Ai::GenerationError before domain output is saved. Verify with bundle exec rspec spec/agents/ai/text_generation_spec.rb spec/services/message_drafts spec/services/relationship_briefings spec/services/memory_extractions.
