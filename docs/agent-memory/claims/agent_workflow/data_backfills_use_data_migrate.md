---
id: agent_workflow.data_backfills_use_data_migrate
type: rule
system: agent_workflow
status: current
confidence: high
severity: important

title: Data backfills use data_migrate

claim: >
  Data backfills must live in data_migrate migrations under db/data instead of
  schema migrations under db/migrate. Schema migrations should own structural
  database changes, while data migrations should own historical data updates and
  should batch larger updates when practical to reduce lock duration.

source_files:
  - Gemfile
  - bin/setup
  - db/data/20260705160100_backfill_user_onboarding_completed_at.rb
  - db/migrate/20260705160000_add_onboarding_state_to_users.rb
  - db/data_schema.rb
related_files:
  - AGENTS.md
symbols:
  - BackfillUserOnboardingCompletedAt
routes: []
tags:
  - data_migrate
  - migrations
  - backfills

verification:
  - bin/setup --skip-server
last_verified_commit: null
---

# Data backfills use data_migrate

## Rule

Data backfills must live in `data_migrate` migrations under `db/data` instead of
schema migrations under `db/migrate`.

Schema migrations should own structural database changes. Data migrations should
own historical data updates, and larger updates should batch records when
practical to reduce lock duration during deploys.

Local setup runs `bin/rails db:prepare:with_data` so pending data migrations are
applied as part of the standard repository setup and CI preparation path.

## Severity

Important.

## Why It Matters

Mixing data backfills into schema migrations can hold locks inside structural
migration transactions and makes deploy risk harder to reason about. Keeping
backfills in `db/data` preserves a clear operational boundary and lets
`data_migrate` track historical data changes separately.

## Verification

- `bin/rails -T data`
- `bin/setup --skip-server`
- `bin/rails data:migrate`
- `bin/rubocop`
