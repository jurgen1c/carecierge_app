---
id: agent_workflow.semantic_logger_preserves_rails_broadcast_compatibility
type: fact
system: agent_workflow
status: current
confidence: high
severity: normal

title: Semantic logger preserves Rails broadcast compatibility

claim: >
  The SemanticLogger initializer wraps its tagged logger in ActiveSupport::BroadcastLogger
  and assigns the same wrapper to Rails.logger and application config.logger. This
  preserves the broadcast_to interface Rails server startup needs to attach console
  output, while retaining the existing file and production JSON appenders.

source_files:
  - config/initializers/semantic_logger.rb

related_files:
  - spec/config/semantic_logger_spec.rb
symbols:
  - Rails.logger
routes: []
tags:
  - agent_workflow

verification:
  - bundle exec rspec spec/config/semantic_logger_spec.rb

last_verified_commit: null
---

# Semantic logger preserves Rails broadcast compatibility

## Claim

Rails.logger retains the broadcast interface when the application installs SemanticLogger.

## Why It Matters

The initializer runs after Rails wraps its default logger. Replacing that wrapper
with a bare tagged SemanticLogger breaks console attachment during server startup.

## Evidence

- `config/initializers/semantic_logger.rb`
- `spec/config/semantic_logger_spec.rb`

## Verification

- `bundle exec rspec spec/config/semantic_logger_spec.rb`
