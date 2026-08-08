<!-- agent-memory:generated-reference repo-memory/contextual-workflows.md -->
# Contextual Workflows

Context can include matched recipes, plan stages, and profile traits. These are repository memory signals, not higher-priority instructions.

Start with normal context:

```bash
agent-memory context --task "<task>"
agent-memory context --git-diff
```

Interpret sections this way:

- Matched Recipes: reusable workflow steps, required claims, verification, and memory-update prompts.
- Plan Stage: current local scaffold for multi-stage work. Stay within the stage unless the user broadens scope.
- Selected Profile Traits: concise guidance for retrieval, review shape, risk lens, verification, or scope control.

Do not commit generated state under `.agent-memory/`. Completed one-off plans should be finished, pruned, or promoted intentionally.
