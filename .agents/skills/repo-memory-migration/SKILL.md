---
name: repo-memory-migration
description: Use this skill when migrating existing repository documentation into agent-memory atomic claims, graph relationships, indexes, recipes, and waivers.
version: 0.1.0
user-invocable: false
---

# Repo Memory Migration Skill

Use this skill when migrating existing repository documentation into `agent-memory`.

The goal is to convert legacy docs into atomic, reviewable memory that matches this tool's expected files:

- claims: `docs/agent-memory/claims/**/*.md`
- graphs: `docs/agent-memory/graph/**/*.yaml`
- indexes: `docs/agent-memory/indexes/**/*.yaml`
- recipes: `docs/agent-memory/recipes/**/*.yaml`

Generated memory lives in `.agent-memory/memory.sqlite`. Do not edit or commit generated SQLite.

## Migration Workflow

Start with a scan:

```bash
bin/memory migrate-docs --from <existing-docs> --system <system>
```

For automatic starter drafts, opt in explicitly:

```bash
bin/memory migrate-docs --from <existing-docs> --system <system> --automatic
```

Automatic migration creates `current`, low-confidence claim drafts. Treat them as starting points that still need review and verification.

## Agent Duties

- Read the source docs and split broad prose into one atomic claim per file.
- Keep migrated claims low-confidence until verified against code, and update or deprecate them if code disagrees.
- Reference the original doc path in `source_files`.
- Create indexes for watched files and systems.
- Create graph edges for relationships such as `requires`, `constrains`, `explains`, `conflicts_with`, `replaces`, `verifies`, and `same_area`.
- Use templates instead of inventing structure.

Useful commands:

```bash
bin/memory templates list
bin/memory templates show claim:fact
bin/memory validate
bin/memory compile
bin/memory doctor
```

If migrated memory conflicts with code, trust code and update or deprecate the memory.
