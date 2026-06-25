---
id: agent_workflow.tool_version_source_of_truth
type: rule
system: agent_workflow
status: current
confidence: high
severity: important

title: Tool versions use .tool-versions as source of truth

claim: >
  Repository tool versions are tracked in .tool-versions. CI must set Ruby explicitly to
  the same Ruby version, and Dockerfile RUBY_VERSION comments and values must stay aligned
  with .tool-versions rather than a removed .ruby-version file.

source_files:
  - .tool-versions
  - .github/workflows/ci.yml
  - Dockerfile

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
  - rg -n ruby-version .github/workflows/ci.yml
  - rg -n RUBY_VERSION Dockerfile
  - rg -n ruby .tool-versions
last_verified_commit: null
---

# Tool versions use .tool-versions as source of truth

## Claim

Repository tool versions are tracked in `.tool-versions`. CI must set Ruby explicitly to the
same Ruby version, and Dockerfile `RUBY_VERSION` comments and values must stay aligned with
`.tool-versions` rather than a removed `.ruby-version` file.

## Why It Matters

CI, container builds, and local development should run the same runtime versions. Stale
references to `.ruby-version` or implicit Ruby setup can let CI drift from local tooling.

## Evidence

- `.tool-versions`
- `.github/workflows/ci.yml`
- `Dockerfile`

## Verification

- `rg -n ruby-version .github/workflows/ci.yml`
- `rg -n RUBY_VERSION Dockerfile`
- `rg -n ruby .tool-versions`
