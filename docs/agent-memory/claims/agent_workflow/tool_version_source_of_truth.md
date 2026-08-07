---
id: agent_workflow.tool_version_source_of_truth
type: rule
system: agent_workflow
status: current
confidence: high
severity: important

title: Tool versions use repository files as sources of truth

claim: >
  Repository tool versions are tracked in .tool-versions. Dockerfile RUBY_VERSION
  comments and values must stay aligned with .tool-versions rather than a removed
  .ruby-version file. The agent-memory CLI is pinned in package.json and bun.lock,
  with bin/memory preferring the local node_modules binary before global or bunx
  fallback execution. Transitive JavaScript security pins belong in explicit
  package.json overrides and the generated bun.lock. agent-memory.config.yaml
  owns canonical memory paths and validation defaults. GitHub Actions CI is
  intentionally absent because local bin/ci signoff is the PR quality gate.

source_files:
  - .tool-versions
  - Dockerfile
  - bin/memory
  - agent-memory.config.yaml
related_files:
  - package.json
  - bun.lock
symbols: []
routes: []
tags:
  - tooling
  - agent-memory

verification:
  - bin/memory --version
  - bin/memory sync
  - bin/memory doctor
  - bun audit
  - test ! -f .github/workflows/ci.yml
  - rg -n RUBY_VERSION Dockerfile
  - rg -n ruby .tool-versions
last_verified_commit: null
---

# Tool versions use repository files as sources of truth

## Claim

Repository tool versions are tracked in `.tool-versions`. Dockerfile `RUBY_VERSION`
comments and values must stay aligned with `.tool-versions` rather than a removed
`.ruby-version` file.

The agent-memory CLI is pinned in `package.json` and `bun.lock`. `bin/memory`
must prefer the repository-local `node_modules/.bin/agent-memory` binary before a
global executable or `bunx @jurgen1c/agent-memory-cli` fallback. The durable
memory paths and validation defaults are owned by `agent-memory.config.yaml`.
Transitive JavaScript security pins must be explicit `package.json` overrides
and reflected in `bun.lock`, rather than undeclared top-level dependencies.

GitHub Actions CI is intentionally absent because local `bin/ci` signoff is the
PR quality gate.

## Why It Matters

Container builds and local development should run the same runtime versions. Stale
references to `.ruby-version` or implicit runtime setup can let tooling drift from
local development. The agent-memory wrapper must also resolve the checked-in
dependency first so repository memory commands use the version recorded in the
lockfile.

## Evidence

- `.tool-versions`
- `Dockerfile`
- `AGENTS.md`
- `package.json`
- `bun.lock`
- `bin/memory`
- `agent-memory.config.yaml`

## Verification

- `bin/memory --version`
- `bin/memory sync`
- `bin/memory doctor`
- `bun audit`
- `test ! -f .github/workflows/ci.yml`
- `rg -n RUBY_VERSION Dockerfile`
- `rg -n ruby .tool-versions`
