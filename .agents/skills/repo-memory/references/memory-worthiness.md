<!-- agent-memory:generated-reference repo-memory/memory-worthiness.md -->
# Memory Worthiness

Durable memory should reduce future uncertainty, rework, or risk. It should not become a changelog or a transcription of the codebase.

## Before Creating Anything

1. Search existing claims and recipes. Update, deprecate, or extend the artifact that already owns the knowledge.
2. Identify the smallest durable proposition or repeatable procedure.
3. Check the repository's claim source policy.
4. Choose the narrowest artifact that represents the knowledge without duplication.

## Claim Threshold

A new claim should normally pass at least four of these five tests:

1. **Repository-specific**: this is not generic engineering knowledge.
2. **Future-relevant**: a later implementation, debugging, review, release, or operations task is likely to need it.
3. **Durable**: it should remain true after the current branch or task is complete.
4. **Consequential**: forgetting it could cause an incorrect change, security or reliability risk, repeated investigation, or a broken workflow.
5. **Evidence-backed**: code, tests, configuration, committed documentation, or another concrete source can verify it.

Atomicity and verification are necessary but not sufficient. A perfectly formatted claim can still be noise.

## Choose the Artifact

- **Update an existing claim** when the same durable truth changed or gained better evidence.
- **Create a claim** for one durable fact, rule, constraint, decision, risk, or lifecycle invariant.
- **Create a recipe** for a recurring agent procedure with repository-specific steps, ordering, safeguards, decision points, or verification.
- **Update an index** for discoverability, ownership, watched files, routes, jobs, models, tags, or search terms.
- **Use a local plan run** for one-off task execution state.
- **Use a waiver** for an intentional, reviewed, time-boxed coverage exception.
- **Create nothing** for formatting-only work, routine refactors, temporary debugging observations, generic best practices, speculative assumptions, or facts obvious from one local definition.

## Claim or Recipe?

A claim tells a future agent **what is true or must remain true**. A recipe tells a future agent **how to perform a recurring task safely**.

Good claim:

> OAuth identity resolution requires both the provider identifier and tenant context.

Noisy claim:

> The OAuth controller calls `Student.find_by`.

Good recipe:

> Rotate the signing key by updating credentials, regenerating fixtures, running compatibility tests, and verifying that old tokens fail.

Noisy recipe:

> Edit the file, run tests, and commit.

Use a workflow claim for a durable lifecycle or mandatory transition. Use a first-class YAML recipe for steps an agent performs. The legacy `claim:recipe` template is compatibility-only and should not be the default for new procedures.

Both `new claim` and `new recipe` create `needs_review` drafts. Replace all TODO values and complete verification before promotion to `current`. A current artifact containing TODO placeholders is invalid.

## Coverage Is Not Evidence of Worth

A changed watched file or coverage gap is a prompt to review memory, not proof that a new claim is needed. The correct response may be to update existing memory, improve an index, add a justified waiver, change the claim source policy, or make no memory change. Never create filler claims or false graph relationships to clear a check.

## Claim Source Policy

`claim_sources.allow` and `claim_sources.deny` contain repo-relative glob patterns. An empty allow list permits every repository path. Deny patterns always win.

- Allowed claim sources: all repository paths
- Denied claim sources: none

Policy-excluded paths cannot appear in claim `source_files` or `related_files`, and changed files excluded by the policy do not require claim coverage. Do not bypass the policy by attaching an excluded path indirectly to an otherwise allowed claim.
