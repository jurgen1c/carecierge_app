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
  app/helpers/style_variants_helper.rb for reusable component class variants, and avoid relying
  on nonexistent STYLE_GUIDE.md or .impeccable/design.json files.

source_files:
  - AGENTS.md
  - PRODUCT.md
  - DESIGN.md
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
  - test -f PRODUCT.md && test -f DESIGN.md && test -f app/helpers/style_variants_helper.rb && test ! -e STYLE_GUIDE.md && test ! -e .impeccable/design.json
last_verified_commit: null
---

# Frontend policy uses product and design docs plus StyleVariants

## Claim

Frontend work must treat `PRODUCT.md` and `DESIGN.md` as the UI source-of-truth documents, use
`app/helpers/style_variants_helper.rb` for reusable component class variants, and avoid relying
on nonexistent `STYLE_GUIDE.md` or `.impeccable/design.json` files.

## Why It Matters

Agents should not block on missing style-guide artifacts or invent styling workflows when the
repo already has product/design docs and a StyleVariants helper.

## Evidence

- `AGENTS.md`
- `PRODUCT.md`
- `DESIGN.md`
- `app/helpers/style_variants_helper.rb`

## Verification

- `test -f PRODUCT.md && test -f DESIGN.md && test -f app/helpers/style_variants_helper.rb && test ! -e STYLE_GUIDE.md && test ! -e .impeccable/design.json`
