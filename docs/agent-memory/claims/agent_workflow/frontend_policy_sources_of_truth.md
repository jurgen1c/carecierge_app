---
id: agent_workflow.frontend_policy_sources_of_truth
type: rule
system: agent_workflow
status: current
confidence: high
severity: important

title: Frontend policy uses product and design docs plus StyleVariants

claim: >
  Frontend work must treat PRODUCT.md and DESIGN.md as the UI source-of-truth documents, use
  the semantic Tailwind palette in app/assets/stylesheets/application.tailwind.css, consume
  app/helpers/style_variants_helper.rb for reusable component class variants, and keep
  .impeccable/design.json regenerated with DESIGN.md. STYLE_GUIDE.md is not authoritative.

source_files:
  - AGENTS.md
  - PRODUCT.md
  - DESIGN.md
  - .impeccable/design.json
  - app/assets/stylesheets/application.tailwind.css
  - app/helpers/style_variants_helper.rb

related_files:
  - .impeccable/live/config.json
symbols:
  - StyleVariantsHelper
routes: []
tags:
  - agent_workflow
  - frontend
  - design-system

verification:
  - test -f PRODUCT.md && test -f DESIGN.md && test -f .impeccable/design.json && test -f app/assets/stylesheets/application.tailwind.css && test -f app/helpers/style_variants_helper.rb && test ! -e STYLE_GUIDE.md
last_verified_commit: null
---

# Frontend policy uses product and design docs plus StyleVariants

## Claim

Frontend work must treat `PRODUCT.md` and `DESIGN.md` as the UI source-of-truth documents, use
the semantic Tailwind palette in `app/assets/stylesheets/application.tailwind.css`, consume
`app/helpers/style_variants_helper.rb` for reusable component class variants, and keep
`.impeccable/design.json` regenerated with `DESIGN.md`. `STYLE_GUIDE.md` is not authoritative.

## Why It Matters

Agents should not reopen settled palette choices or invent styling workflows when the repository
already has product/design docs, reusable semantic tokens, a machine-readable design sidecar,
and a StyleVariants helper.

## Evidence

- `AGENTS.md`
- `PRODUCT.md`
- `DESIGN.md`
- `.impeccable/design.json`
- `app/assets/stylesheets/application.tailwind.css`
- `app/helpers/style_variants_helper.rb`

## Verification

- `test -f PRODUCT.md && test -f DESIGN.md && test -f .impeccable/design.json && test -f app/assets/stylesheets/application.tailwind.css && test -f app/helpers/style_variants_helper.rb && test ! -e STYLE_GUIDE.md`
