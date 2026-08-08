<!-- agent-memory:generated-reference repo-memory/coverage-and-validation.md -->
# Coverage And Validation

Run `validate` before finishing memory changes. Run `compile` and `doctor` when retrieval behavior or generated SQLite freshness matters.

Use `coverage --git-diff` for non-trivial code changes. If watched files changed without memory updates, either update the relevant claim, index, recipe, or graph, or add a time-boxed waiver with a clear reason.

## Stale Review

Run `audit --git-diff` when canonical memory files changed. Strong duplicate signals block; shared tags and weak file overlap are advisory. Audit requires `last_verified_commit` values to be full immutable Git commit object IDs and warns when supporting files changed afterward. Re-run verification and record the full tested commit object ID, or move the claim to `needs_verification`. Resolve failures by reviewing the exact shared values and then updating or deprecating a claim, or adding any semantically accurate explicit graph relationship. Never invent `replaces` or `conflicts_with` solely to clear an audit finding. Repositories that intentionally depend on the legacy all-overlap gate can run `audit --git-diff --strict`.

All Git subprocesses are bounded. If a restricted subprocess stalls, agent-memory terminates it and follows the command's documented warning or fallback behavior. Audit conservatively retains current-tree overlap findings when baseline memory cannot be loaded.

Generated files under `.agent-memory/` are cache data and must not be committed.
