---
name: repo-memory
description: Use this skill whenever working in this repository to sync and retrieve agent-memory context before code changes and update durable claims when behavior or critical repository knowledge changes.
version: 0.4.0
user-invocable: false
---

<!-- agent-memory:generated-skill repo-memory -->
# Repo Memory Skill

Use this skill whenever working in this repository.

This repository uses `agent-memory`, a local memory system based on atomic claims, graph relationships, recipes, indexes, and waivers.

For deeper task guidance, read:

- `references/claims.md`
- `references/memory-worthiness.md`
- `references/contextual-workflows.md`
- `references/recipes.md`
- `references/plans.md`
- `references/profiles.md`
- `references/graphs-and-indexes.md`
- `references/coverage-and-validation.md`
- `references/delegation.md`


Canonical memory lives in:

- claims: `docs/agent-memory/claims/**/*.md`
- graphs: `docs/agent-memory/graph/**/*.yaml`
- indexes: `docs/agent-memory/indexes/**/*.yaml`
- recipes: `docs/agent-memory/recipes/**/*.yaml`
- plans: `docs/agent-memory/plans/**/*.yaml`
- profiles: `docs/agent-memory/profiles/**/*.yaml`
- waivers: `docs/agent-memory/waivers/**/*.yaml`

Generated memory lives in:

- `.agent-memory/memory.sqlite`
- `.agent-memory/plans` for local one-off plan runs

Do not edit or commit the SQLite database, local plan runs under `.agent-memory/plans`, or other generated files under `.agent-memory`.

## Before Work

Run:

```bash
bin/memory sync
```

Then retrieve task context:

```bash
bin/memory context --task "<task>"
```

If files are already known:

```bash
bin/memory context --changed-files <file1> <file2>
```

If working from an existing diff:

```bash
bin/memory context --git-diff
```

Use the returned contextual workflows:

- If context includes matched recipes, follow their required claims, verification, and memory-update prompts.
- If context includes a plan stage, work that stage unless the user broadens scope.
- If context includes profile traits, treat them as repository guidance below system, developer, user, and repository instruction-file guidance.
- For multi-stage work, use `bin/memory plans suggest --task "<task>"` and create a local run only when it adds value.

## Available Commands

- `sync`: Run before agent work or after checkout, merge, pull, or rebase.
- `context`: Run before editing code so relevant claims, recipes, and verification steps are visible.
- `coverage`: Run before finishing work, especially in CI or when watched files changed.
- `audit`: Run before finishing when canonical memory files changed.
- `query`: Use when you need memory about a behavior, subsystem, file, symbol, or route.
- `show`: Use when you need exact claim metadata, linked files, tags, or graph context.
- `system`: Use before editing a subsystem to inspect critical claims, recipes, watched files, and graph activity.
- `recipes`: Use when you need a workflow package with required claims, steps, files, and verification.
- `plans`: Use for multi-stage work where an agent should follow explicit stages, gather stage context, and close out local state.
- `profiles`: Use when you need explainable guidance for reviews, architecture work, implementation scope, releases, or migrations.
- `templates`: Use before creating claims so new memory follows the supported shape.
- `migrate-docs`: Use when adopting agent-memory in a repo with existing documentation.
- `new claim`: Use when durable behavior, architecture, risk, decisions, or constraints changed and existing memory does not own it.
- `new recipe`: Use when future agents need repository-specific recurring steps, safeguards, and verification.
- `validate`: Run before finishing changes to catch invalid claims, graphs, indexes, recipes, and waivers.
- `compile`: Run after changing canonical memory or before retrieval if the database is missing.
- `doctor`: Run when retrieval fails or after repository state changes.
- `upgrade`: Run after upgrading the agent-memory package version in a repository.

## Templates

Use templates instead of inventing claim structure:

```bash
bin/memory templates list
bin/memory templates show claim:fact
bin/memory new claim --type fact --system <system> --title "<title>"
bin/memory new recipe --system <system> --title "<title>"
```

New claims and recipes are safe drafts. Claims start as `needs_review` with low confidence. Replace every TODO, run verification, and only then promote a claim or recipe to `current`. Current artifacts containing TODO placeholders fail validation.

## Decide Whether to Write Memory

Search for existing claims and recipes before creating new memory. Update or deprecate an existing artifact when it already owns the knowledge.

Create durable memory only when the knowledge is repository-specific, likely to matter in future work, durable beyond the current task, consequential if forgotten, and supported by concrete evidence. A new claim should normally satisfy at least four of those five tests.

- Use a claim for one durable truth or invariant.
- Use a recipe for a repeatable agent procedure with repository-specific steps, ordering, safeguards, or verification.
- Use an index for discoverability or file ownership.
- Use a local plan run for one-off execution state.
- Use a waiver for a reviewed, time-boxed coverage exception.
- Create nothing for temporary observations, routine refactors, generic advice, or facts obvious from one local definition.

A claim tells future agents what is true or must remain true. A recipe tells future agents how to perform a recurring task safely. Never create placeholder memory merely because code changed or coverage reported a gap.

When claim verification succeeds, set `last_verified_commit` to the tested full Git commit object ID, never a movable ref such as a branch or `HEAD`. Use `confidence: verified` only with that commit recorded. Audit warns when supporting files changed after the recorded commit.

Claim source eligibility comes from `claim_sources` in `agent-memory.config.yaml`:

- Allowed claim sources: all repository paths
- Denied claim sources: none

Deny patterns win over allow patterns. Do not reference policy-excluded paths through either `source_files` or `related_files`.

## Relationship Graphs

Relationships between claims live in graph files such as `docs/agent-memory/graph/**/*.yaml`.

Use graph files to connect claims with relationships like `requires`, `constrains`, `explains`, `conflicts_with`, `replaces`, `verifies`, and `same_area`.

Do not duplicate relationship metadata in every claim file.

## After Work

If behavior changed, update or add atomic claims. Before finishing:

```bash
bin/memory validate
bin/memory compile
bin/memory doctor
bin/memory coverage --git-diff
```

If any canonical memory file changed, also run:

```bash
bin/memory audit --git-diff
```

## When to Update Memory

Update memory when:

- behavior changed
- architecture changed
- a workflow changed
- a critical constraint was discovered
- a previous claim became stale
- a reusable recipe was discovered

Do not update durable memory for formatting-only changes, speculative assumptions, or temporary debugging notes.

When a one-off plan run is complete, run `bin/memory plans finish <id>` or prune old local runs with `bin/memory plans prune`. Promote a completed run only when it describes a reusable workflow.

If memory conflicts with code, trust code and update or deprecate memory.
