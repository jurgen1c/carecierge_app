# AGENTS.md

## Purpose
This repository uses an agentic workflow. Agents must produce reviewable artifacts, respect ownership boundaries, and avoid unscoped changes. The goal is: predictable diffs, strong tests, and up-to-date agent-readable memory.

## Global Non-Negotiables
- **No hallucination**: If information is unknown, say so and propose how to verify.
- **Small, scoped changes**: Prefer incremental diffs over broad refactors.
- **Deterministic artifacts**: Plans, acceptance criteria, review reports, and memory patches must be explicit and saved.
- **Security and tenancy first**: Never leak data across tenants. Assume all inputs are untrusted.
- **Localization baseline is mandatory**: Always keep both `en` and `es` locales configured; `en` must remain the default locale and `es` must remain available.

### Definition of Done (DoD)
A task/feature is **Done** only when all are true:
- Acceptance criteria are met (explicitly confirmed).
- Tests are **green** (unit + integration as required).
- Reviews are completed and **blockers resolved**.
- Agent-memory updates are applied when behavior, architecture, workflow, or critical constraints change.
- Agent-memory artifacts remain valid and consistent (`docs/agent-memory/claims`, `graph`, `indexes`, `recipes`, `waivers`).
- No unauthorized files were modified (see “Edit boundaries”).

## Edit Boundaries
- Engineers may change application code within approved scopes (typically `app/`, `lib/`, `spec/`, `config/`)

## Agent Memory Knowledge Base
Durable repository knowledge lives in:
- `docs/agent-memory/`

It must remain:
- queryable through `bin/memory context`, `bin/memory query`, `bin/memory show`, and `bin/memory system`
- versioned and reviewable

Generated memory lives in `.agent-memory/` and must not be committed.

### Agent-Memory-First Workflow (Required)
Before planning or writing code, agents must resolve context in this order:
1. Run `bin/memory sync` so the generated SQLite cache matches committed memory.
2. Run `bin/memory context --task "<task>"` before planning non-trivial work.
3. If files are already known, run `bin/memory context --changed-files <file1> <file2>`.
4. If working from an existing diff, run `bin/memory context --git-diff`.
5. Use `bin/memory query`, `bin/memory show`, or `bin/memory system` when more precise claim, graph, recipe, or watched-file context is needed.

Agents must cite the relevant memory claim IDs, system IDs, and verification commands they used in their plan/PR notes when the task is non-trivial.

### Agent Memory Update Rules
Update agent memory in the same change when durable repository knowledge changes.

- If a system boundary, interface, auth rule, or dependency changes:
  - add or update atomic claims under `docs/agent-memory/claims/<system>/`
- If a trigger/handoff/failure mode between systems changes:
  - update graph relationships under `docs/agent-memory/graph/`
- If route/job/model discoverability changes:
  - update watched files and default queries under `docs/agent-memory/indexes/`
- If implementation details change:
  - update the relevant claim `source_files`, `related_files`, `symbols`, `routes`, and `verification`
- If a repeatable workflow is discovered:
  - add or update a recipe under `docs/agent-memory/recipes/`

Use `bin/memory templates list` and `bin/memory templates show <template>` before creating new memory artifacts.

### Agent Memory Status and Consistency
- Claim status values must be one of: `current`, `proposed`, `stale`, `deprecated`, `experimental`, `needs_verification`, `needs_review`, `rejected`.
- Claim confidence values must be one of: `low`, `medium`, `high`, `verified`.
- Every durable claim about behavior must map to at least one source file and one verification step.
- Prefer one atomic claim per file.
- Keep graph edges referencing valid claim IDs.
- Keep indexes focused on discoverability: claim globs, default queries, watched files, and tags.
- Run `bin/memory validate` and `bin/memory sync` before finishing any change that touches memory.

## Testing Policy (Rails)
- Backend changes must follow **TDD**: failing test first, then implementation, then green.
- Prefer:
  - request/integration specs for end-to-end behavior
  - unit specs for edge cases and service objects/operations
- Tests must be deterministic (no flaky sleeps; prefer time helpers and proper synchronization). Timecop should be used
- If a feature introduces async behavior, include explicit test coverage for:
  - job enqueueing
  - job execution side effects
  - broadcasts (if any)

## Frontend Policy (Rails + Turbo)
- UI should use the project design system (tokens, components, patterns).
- Agents must treat `PRODUCT.md` and `DESIGN.md` as the first-stop style authorities for UI changes:
  - `PRODUCT.md` for product/register strategy, users, brand personality, anti-references, design principles, and accessibility baseline.
  - `DESIGN.md` for visual tokens, component rules, elevation, typography, and Do/Don't guardrails.
- Before planning or implementing frontend/UI changes, agents must read and follow `PRODUCT.md` and `DESIGN.md`.
- Reusable component styling must use `app/helpers/style_variants_helper.rb` for base classes, variants, defaults, and compound variants. Do not invent scattered conditional class strings when a ViewComponent style variant is appropriate.
- Use the `$impeccable` skill for frontend design work, including app shells, dashboards, forms, settings, onboarding, empty states, UX copy, responsive behavior, accessibility polish, visual audits, and component extraction. Do not invoke it for backend-only work.
- When building a new view or substantially new user-facing surface, agents must use `$impeccable craft <surface or feature>` before implementation unless the user has already provided a concrete design brief with acceptance criteria.
- If the task is to build or substantially change a UI, prefer `$impeccable shape <surface>` or `$impeccable craft <feature>` before implementation unless the user has already supplied a concrete design brief.
- If the task is to improve an existing UI, choose the narrowest useful command:
  - `$impeccable critique <surface>` for a scored UX review.
  - `$impeccable audit <surface>` for accessibility, performance, responsive, and technical UI checks.
  - `$impeccable polish <surface>` for pre-ship visual and interaction refinement.
  - `$impeccable layout`, `typeset`, `colorize`, `clarify`, `adapt`, `harden`, or `onboard` when the weakness is specific.
- For visual-system changes, update `PRODUCT.md` and `DESIGN.md` together when applicable. If `.impeccable/design.json` is generated in the repo, regenerate it with `$impeccable document` whenever `DESIGN.md` changes. Preserve Carecierge's `PRODUCT.md` positioning and `DESIGN.md` direction unless the user explicitly asks for a redesign.
- `$impeccable live` is available for browser-based visual iteration; live mode is configured through `.impeccable/live/config.json`.
- Reusable UI must use the ViewComponent gem when the element appears in more than one place, carries variants/state, or forms part of the design system. Prefer Lookbook previews and focused component specs for reusable UI.
- ViewComponents must use `dry-initializer` for options, following the application component base pattern.
- ViewComponent styles must use `app/helpers/style_variants_helper.rb` for base styles, variants, defaults, and compound variants instead of scattered conditional class strings.
- Rails views must use ERB templates and Rails view best practices: semantic HTML, Rails helpers, accessible forms, partials for local one-off composition, ViewComponent for reusable composition, Rails I18n for user-facing copy, and no inline styles.
- ERB templates must render ViewComponents through the `component` helper from `app/helpers/application_helper.rb` rather than manually instantiating component classes inline.
- UI should be mobile first.
- Turbo/Stimulus changes must include verification:
  - correct DOM targets
  - progressive enhancement behavior
  - accessibility basics (keyboard, focus, aria where relevant)

## Localization Policy (Rails I18n)
- Use Rails standard I18n (`I18n.t` / `t`) for user-facing copy.
- Keep `config.i18n.available_locales` including both `:es` and `:en`.
- Keep `config.i18n.default_locale` set to `:en`.
- Do not remove or regress Spanish support while adding/updating English translations.

## Data & Performance
- Any DB migration must be reviewed for:
  - locking risk
  - index strategy
  - reversibility where practical
- UUID key policy for migrations:
  - always define new tables with `id: :uuid`
  - always define relational columns with `type: :uuid` on `references` / `belongs_to` / `add_reference`
  - avoid implicit integer/bigint defaults for IDs and foreign keys
- Ransack gem is desired search mechanism
- Any query-heavy feature should consider:
  - N+1 avoidance
  - pagination strategy (Pagy)
  - caching correctness (Solid Cache) when used

## Security
- Authorization must be enforced (Pundit where applicable).
- Avoid logging sensitive data.
- Validate and permit parameters explicitly.

## Project Dependencies (key)
- Rails (web framework): https://guides.rubyonrails.org/
- Turbo (Hotwire): https://turbo.hotwired.dev/
- Stimulus (Hotwire): https://stimulus.hotwired.dev/
- Solid Cache: https://guides.rubyonrails.org/caching_with_rails.html
- Solid Queue: https://guides.rubyonrails.org/active_job_basics.html
- Solid Cable: https://guides.rubyonrails.org/action_cable_overview.html
- Pagy (pagination) — version 43: https://ddnexus.github.io/pagy/
- ViewComponent: https://viewcomponent.org/
- Ransack (search/filtering): https://github.com/activerecord-hackery/ransack
- Pundit (authorization): https://github.com/varvet/pundit
- Devise (authentication): https://github.com/heartcombo/devise
- OmniAuth Google OAuth2: https://github.com/zquestz/omniauth-google-oauth2
- RSpec Rails: https://github.com/rspec/rspec-rails
- FactoryBot Rails: https://github.com/thoughtbot/factory_bot_rails
- Lookbook (ViewComponent previews): https://lookbook.build/
- Noticed

## Documentation & Developer Experience
- DX Writer: maintains developer-facing docs, runbooks, setup instructions, and "how to test" notes.
  - DX Writer writes/updates non-memory documentation directly (e.g., README, runbooks) within scope.
- Local CI is the source of truth for PR verification:
  - `bin/setup` must configure `core.hooksPath` to `.githooks`.
  - Agents must use normal `git push`; do not use `--no-verify` or `TRAIL_CROWD_AFTER_PUSH_CI=false` unless the user explicitly approves bypassing the after-push local CI queue.
  - After pushing, check the `local-ci-after-push.log` file in the actual git directory (normally `.git/local-ci-after-push.log`) or run `bin/ci` directly to verify that local CI passed and `gh signoff` reported the commit status.
  - GitHub Actions CI is intentionally disabled for pull requests, pushes, and manual dispatch. Do not add a manual fallback workflow.
  - `gh signoff` intentionally requires the `gh` CLI and the `basecamp/gh-signoff` extension.

## Observability & Reliability
- ensures features include appropriate instrumentation and operational visibility.
  - Adds/updates logging conventions, metrics/tracing hooks, and job/cache instrumentation where relevant.
  - Coordinates with DevOps/Infrastructure for environment-level telemetry and alerting patterns.

## When to Stop and Ask
Agents should ask for clarification (via Product Analyst or directly) when:
- acceptance criteria are ambiguous
- business rules are missing or conflicting
- the change touches payment, security boundaries, or tenant isolation and requirements are unclear

## Rails
Agents must use standard Rails commands, such as:
- bin/rails db:migrate
- bin/rails g model <Model Name> <attributes>
- bin/rails g migraiton  <Migration Name> <attributes>
- bundle exec rspec
