---
name: repo-memory
description: Use this skill whenever working in this repository to sync and retrieve agent-memory context before code changes and update durable claims when behavior or critical repository knowledge changes.
version: 0.1.0
user-invocable: false
---

# Repo Memory Skill

Use this skill whenever working in this repository.

This repository uses `agent-memory`, a local memory system based on atomic claims, graph relationships, recipes, indexes, and waivers.

Canonical memory lives in:

- claims: `docs/agent-memory/claims/**/*.md`
- graphs: `docs/agent-memory/graph/**/*.yaml`
- indexes: `docs/agent-memory/indexes/**/*.yaml`
- recipes: `docs/agent-memory/recipes/**/*.yaml`
- waivers: `docs/agent-memory/waivers/**/*.yaml`

Generated memory lives in:

- `.agent-memory/memory.sqlite`

Do not edit or commit the SQLite database or other generated files under `.agent-memory`.

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

## Available Commands

- `sync`: Run before agent work or after checkout, merge, pull, or rebase.
- `context`: Run before editing code so relevant claims, recipes, and verification steps are visible.
- `coverage`: Run before finishing work, especially in CI or when watched files changed.
- `query`: Use when you need memory about a behavior, subsystem, file, symbol, or route.
- `show`: Use when you need exact claim metadata, linked files, tags, or graph context.
- `system`: Use before editing a subsystem to inspect critical claims, recipes, watched files, and graph activity.
- `templates`: Use before creating claims so new memory follows the supported shape.
- `migrate-docs`: Use when adopting agent-memory in a repo with existing documentation.
- `new claim`: Use when behavior, architecture, workflow, or constraints changed.
- `validate`: Run before finishing changes to catch invalid claims, graphs, indexes, recipes, and waivers.
- `compile`: Run after changing canonical memory or before retrieval if the database is missing.
- `doctor`: Run when retrieval fails or after repository state changes.

## Templates

Use templates instead of inventing claim structure:

```bash
bin/memory templates list
bin/memory templates show claim:fact
bin/memory new claim --type fact --system <system> --title "<title>"
```

Create one Markdown file per claim. Keep claims atomic and include verification steps.

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

## When to Update Memory

Update memory when:

- behavior changed
- architecture changed
- a workflow changed
- a critical constraint was discovered
- a previous claim became stale
- a reusable recipe was discovered

Do not update durable memory for formatting-only changes, speculative assumptions, or temporary debugging notes.

If memory conflicts with code, trust code and update or deprecate memory.
