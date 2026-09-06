---
id: agent_workflow.development_journeys_use_isolated_synthetic_records
type: fact
system: agent_workflow
status: current
confidence: high
severity: important
title: Development journeys use isolated synthetic records
claim: >
  development:seed is an opt-in development-only fixture world separate from db:seed.
  It uses deterministic reserved ca105000 UUIDs, fictional confirmed .example accounts,
  an explicit reference date, validated domain builders, and transactional reruns.
  Email, OAuth, AI, payments and external actions are not invoked; notifications are
  configured for in-app delivery. Feature flags remain unchanged. Reset preflights
  dependent associations and refuses non-seed dependencies before deleting its allowlisted
  records. The journey manifest maps EN/ES personas to available routes and marks billing
  and conversation-import scenarios pending until their dependencies ship.
source_files:
  - lib/development_seeds/world.rb
  - lib/development_seeds/private_journeys.rb
  - lib/development_seeds/shared_journeys.rb
  - lib/tasks/development.rake
  - docs/development/journeys.md
related_files:
  - db/seeds.rb
  - spec/lib/development_seeds/world_spec.rb
  - spec/system/development_journeys_spec.rb
symbols:
  - DevelopmentSeeds::World
routes: []
tags:
  - agent_workflow
  - development
  - seeds
  - isolation
verification:
  - bundle exec rspec spec/lib/development_seeds/world_spec.rb spec/system/development_journeys_spec.rb
  - bin/ci
last_verified_commit: null
---

# Development journeys use isolated synthetic records

The reserved prefix is a seed ownership marker, never a general developer ID convention.
Reset refuses manual dependent records rather than silently deleting them. Existing
synthetic passwords and MFA enrollment are retained by reruns. Real browser actions
remain governed by normal application configuration; the seed command does not create
a global offline mode. Future billing/import work must extend the journey manifest.
