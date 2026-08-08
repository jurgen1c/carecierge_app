<!-- agent-memory:generated-reference repo-memory/claims.md -->
# Claims

Claims are the durable unit of repository memory. Create one Markdown file per atomic behavior, rule, decision, risk, or workflow fact.

Use `templates show claim:fact` or another claim template before creating files. Keep IDs stable, scoped by system, and aligned with the file path under `claims/<system>/`.

Good claims:

- state one thing that can be verified
- name source files, routes, symbols, or tests when known
- include concrete verification steps
- use low confidence until checked against code
- record knowledge that is costly, risky, or time-consuming to rediscover

Avoid broad summaries, temporary implementation notes, and claims that merely restate one obvious local definition. Split a document that describes several behaviors into several claims.

A workflow claim describes a durable lifecycle or invariant, such as required state transitions. It does not replace a YAML recipe. The legacy `claim:recipe` template remains available for compatibility, but use first-class recipes for procedures agents should execute.

`new claim` creates a `needs_review`, low-confidence draft. Replace all TODO fields and run its verification before changing it to `current`. Set `last_verified_commit` to the full tested Git commit object ID when verification succeeds; `confidence: verified` requires that commit.
