# AGENTS.md

## Purpose
This repository uses an agentic workflow. Agents must produce reviewable artifacts, respect ownership boundaries, and avoid unscoped changes. The goal is: predictable diffs, strong tests, and up-to-date canonical documentation.

## Global Non-Negotiables
- **No hallucination**: If information is unknown, say so and propose how to verify.
- **Small, scoped changes**: Prefer incremental diffs over broad refactors.
- **Deterministic artifacts**: Plans, acceptance criteria, review reports, and canonical patches must be explicit and saved.
- **Security and tenancy first**: Never leak data across tenants. Assume all inputs are untrusted.
- **Localization baseline is mandatory**: Always keep both `es` and `en` locales configured; `es` must remain the default locale and `en` must remain available.

### Definition of Done (DoD)
A task/feature is **Done** only when all are true:
- Acceptance criteria are met (explicitly confirmed).
- Tests are **green** (unit + integration as required).
- Reviews are completed and **blockers resolved**.
- Canonical documentation updates are applied (if required by changes).
- Canonical indexes remain valid and consistent (`docs/canonical/index.yml`, `systems`, `interactions`, `lookup`).
- No unauthorized files were modified (see “Edit boundaries”).

## Edit Boundaries
- Engineers may change application code within approved scopes (typically `app/`, `lib/`, `spec/`, `config/`)

## Canonical Knowledge Base
Canonical documentation lives in:
- `docs/canonical/`

It must remain:
- queryable via index routing (`docs/canonical/index.yml` + domain indexes)
- versioned and reviewable

### Canonical-First Workflow (Required)
Before planning or writing code, agents must resolve context in this order:
1. `docs/canonical/systems/index.yml` (system ownership, boundaries, source-of-truth files, specs)
2. `docs/canonical/interactions/index.yml` (cross-system flows, handoffs, failure modes)
3. `docs/canonical/lookup.yml` (route/job/model/capability quick mapping)
4. Domain docs from `docs/canonical/code/index.yml` and architecture indexes

Agents must cite the system IDs and interaction IDs they used in their plan/PR notes when the task is non-trivial.

### Canonical Update Rules
Update canonical docs in the same change when behavior changes.

- If a system boundary, interface, auth rule, or dependency changes:
  - update `docs/canonical/systems/index.yml`
- If a trigger/handoff/failure mode between systems changes:
  - update `docs/canonical/interactions/index.yml`
- If route/job/model discoverability changes:
  - update `docs/canonical/lookup.yml`
- If implementation details change:
  - update corresponding `docs/canonical/code/*/README.md`

Use `docs/canonical/templates/system_readme.md` for new system docs.

### Canonical Status and Consistency
- Status values must be one of: `implemented`, `partial`, `planned`, `deprecated`.
- `last_updated` fields must be quoted strings (`YYYY-MM-DD`) for deterministic YAML parsing.
- New interactions must reference valid system IDs from `docs/canonical/systems/index.yml`.
- Every canonical claim about behavior should map to at least one source file and one spec file.

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
- UI should use the canonical design system (tokens, components, patterns).
- **Must adhere to `STYLE_GUIDE.md` (e.g., no inline styles).**
- Agents must treat `STYLE_GUIDE.md` as the first-stop style authority for UI changes; follow linked docs from there for implementation details (for example, component styling workflows like `StyleVariants`).
- Agents must also use the project design context:
  - `PRODUCT.md` for product/register strategy, users, brand personality, anti-references, design principles, and accessibility baseline.
  - `DESIGN.md` for visual tokens, component rules, elevation, typography, and Do/Don't guardrails.
  - `.impeccable/design.json` as the generated sidecar used by impeccable live/design tooling; regenerate it with `$impeccable document` whenever `DESIGN.md` is regenerated.
- Use the `$impeccable` skill for frontend design work, including app shells, dashboards, forms, settings, onboarding, empty states, UX copy, responsive behavior, accessibility polish, visual audits, and component extraction. Do not invoke it for backend-only work.
- If the task is to build or substantially change a UI, prefer `$impeccable shape <surface>` or `$impeccable craft <feature>` before implementation unless the user has already supplied a concrete design brief.
- If the task is to improve an existing UI, choose the narrowest useful command:
  - `$impeccable critique <surface>` for a scored UX review.
  - `$impeccable audit <surface>` for accessibility, performance, responsive, and technical UI checks.
  - `$impeccable polish <surface>` for pre-ship visual and interaction refinement.
  - `$impeccable layout`, `typeset`, `colorize`, `clarify`, `adapt`, `harden`, or `onboard` when the weakness is specific.
- For visual-system changes, update `STYLE_GUIDE.md`, `DESIGN.md`, and `.impeccable/design.json` together when applicable. Preserve Facturi's current product register and "Quiet Ledger" / "Ledger Emerald" direction unless the user explicitly asks for a redesign.
- `$impeccable live` is available for browser-based visual iteration; live mode is configured through `.impeccable/live/config.json`.
- Prefer ViewComponent + Lookbook previews for reusable UI.
- UI should be mobile first.
- Turbo/Stimulus changes must include verification:
  - correct DOM targets
  - progressive enhancement behavior
  - accessibility basics (keyboard, focus, aria where relevant)

## Localization Policy (Rails I18n)
- Use Rails standard I18n (`I18n.t` / `t`) for user-facing copy.
- Keep `config.i18n.available_locales` including both `:es` and `:en`.
- Keep `config.i18n.default_locale` set to `:es`.
- Do not remove or regress English support while adding/updating Spanish translations.

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
  - DX Writer writes/updates non-canonical documentation directly (e.g., README, runbooks) within scope.
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
Agents must use canonical rails commands, such as:
- bin/rails db:migrate
- bin/rails g model <Model Name> <attributes>
- bin/rails g migraiton  <Migration Name> <attributes>
- bundle exec rspec