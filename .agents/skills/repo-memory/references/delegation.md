<!-- agent-memory:generated-reference repo-memory/delegation.md -->
# Delegation

Use a lower-effort subagent for memory retrieval, broad search, and draft analysis when the task touches several systems, many claims, or an unclear workflow surface. Keep small, obvious lookups inline in the primary agent.

The primary agent owns final interpretation, canonical memory edits, validation, audit signoff, commits, pushes, and external writes.

Good subagent tasks:

- run read-only memory commands such as `context`, `query`, `show`, `system`, `recipes`, `plans`, and `profiles`
- summarize relevant claims, recipes, plan stages, profile traits, and verification steps
- identify candidate stale, deprecated, overlapping, or conflicting claims for primary-agent review
- draft possible claim, graph, recipe, index, profile, or plan-template updates without writing files
- prepare an audit or coverage finding summary with exact IDs, paths, commands, and uncertainty

Do not delegate these tasks:

- editing canonical memory files
- deciding whether a semantic stale or conflict finding is true
- marking audit, coverage, validation, or doctor results as final
- committing, pushing, resolving PR threads, or replying on external services
- treating generated files under `.agent-memory/` as source of truth

Subagent prompt contract:

1. State that the task is read-only and proposal-only.
2. Give exact commands and paths to inspect.
3. Require claim IDs, recipe IDs, plan IDs, profile trait IDs, and file paths in the response.
4. Ask for concise findings grouped by action: use as-is, update, deprecate, replace, conflict, or ignore.
5. Require uncertainty notes when evidence is incomplete.

Before acting on subagent output, the primary agent must verify key claims against source files or command output and rerun the relevant deterministic checks.
