---
id: agent_workflow.local_ci_signoff_gate
type: rule
system: agent_workflow
status: current
confidence: verified
severity: important

title: Local CI signs off GitHub after the full quality gate

claim: >
  bin/ci is the canonical local quality gate. It runs setup, RuboCop, ESLint,
  Bun audit, Bundler Audit, Brakeman, and RSpec before writing the GitHub
  signoff status with gh signoff; CI_SIGNOFF=false runs the same checks without
  writing the signoff status. The signoff step fails on tracked dirty changes or
  unpushed commits, while allowing unrelated untracked local files.

source_files:
  - config/ci.rb
  - package.json
  - eslint.config.mjs
  - AGENTS.md

tags:
  - agent_workflow
  - rule
  - ci
  - signoff
  - security

verification:
  - CI_SIGNOFF=false bin/ci
  - gh extension list

last_verified_commit: null
---

# Local CI signs off GitHub after the full quality gate

## Rule

`bin/ci` is the canonical local quality gate. It runs setup, RuboCop, ESLint,
Bun audit, Bundler Audit, Brakeman, and RSpec before writing the GitHub signoff
status with `gh signoff`.

Use `CI_SIGNOFF=false bin/ci` only when the same quality gate should run without
writing the GitHub signoff status.

The signoff step must fail when tracked files are dirty or the current commit has
not been pushed to the upstream branch. It may allow unrelated untracked local
files so local artifacts do not block signing off a verified pushed commit.

## Severity

Important.

## Why It Matters

Pull request readiness depends on the local gate matching the checks agents run
after a push. Keeping signoff inside `config/ci.rb` prevents separate ad hoc
signoff commands from bypassing tests, lint, or security audits.

## Verification

- `CI_SIGNOFF=false bin/ci`
- `gh extension list`
