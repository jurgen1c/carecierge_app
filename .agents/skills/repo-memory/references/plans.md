<!-- agent-memory:generated-reference repo-memory/plans.md -->
# Plans

Plan templates are canonical reusable workflows. Plan runs under `.agent-memory/plans` are generated local scaffolding for one task.

Useful commands:

```bash
agent-memory plans templates list
agent-memory plans suggest --task "<task>"
agent-memory plans new --template plan_template.<system>.<name> --task "<task>"
agent-memory plans next <plan-run-id>
agent-memory context --plan <plan-run-id> --stage <stage-id>
agent-memory plans complete-stage <plan-run-id> --stage <stage-id> --evidence "<what changed>"
agent-memory plans finish <plan-run-id> --confirm-unresolved
agent-memory plans prune --completed --older-than 7d
agent-memory plans promote <plan-run-id> --to-template
```

Finish or prune local runs after use. Promote only when the completed run describes a reusable workflow; otherwise durable memory belongs in claims, recipes, graph edges, indexes, or profile traits.
