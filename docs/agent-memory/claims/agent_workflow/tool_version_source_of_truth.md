---
id: agent_workflow.tool_version_source_of_truth
type: rule
system: agent_workflow
status: current
confidence: high
severity: important

title: Tool versions use .tool-versions as source of truth

claim: >
  Repository tool versions are tracked in .tool-versions. Dockerfile RUBY_VERSION
  comments and values must stay aligned with .tool-versions rather than a removed
  .ruby-version file. GitHub Actions CI is intentionally absent because local
  bin/ci signoff is the PR quality gate.

source_files:
  - .tool-versions
  - Dockerfile
  - AGENTS.md

related_files:
  - package.json
  - bun.lock
symbols: []
routes: []
tags:
  - agent_workflow
  - tooling
  - ci

verification:
  - test ! -f .github/workflows/ci.yml
  - rg -n RUBY_VERSION Dockerfile
  - rg -n ruby .tool-versions
last_verified_commit: null
---

# Tool versions use .tool-versions as source of truth

## Claim

Repository tool versions are tracked in `.tool-versions`. Dockerfile `RUBY_VERSION`
comments and values must stay aligned with `.tool-versions` rather than a removed
`.ruby-version` file. GitHub Actions CI is intentionally absent because local
`bin/ci` signoff is the PR quality gate.

## Why It Matters

Container builds and local development should run the same runtime versions. Stale
references to `.ruby-version` or implicit runtime setup can let tooling drift from
local development.

## Evidence

- `.tool-versions`
- `Dockerfile`
- `AGENTS.md`

## Verification

- `test ! -f .github/workflows/ci.yml`
- `rg -n RUBY_VERSION Dockerfile`
- `rg -n ruby .tool-versions`
