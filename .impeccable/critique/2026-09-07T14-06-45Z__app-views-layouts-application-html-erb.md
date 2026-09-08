---
target: Carecierge authenticated workspace
total_score: 31
p0_count: 0
p1_count: 0
timestamp: 2026-09-07T14-06-45Z
slug: app-views-layouts-application-html-erb
---
# Carecierge workspace critique and resolution
Target: app/views/layouts/application.html.erb and its authenticated workspace.
Review date: 2026-09-07. Baseline: tmp/ui-audit-2026-09-06.
Assessment A was completed before Assessment B entered synthesis.

## Design health
| Heuristic | Initial | After fixes | Evidence |
|---|---:|---:|---|
| Visibility of status | 3 | 3 | Real due items and bounded counts; factual profile work preview. |
| Match with the real world | 3 | 3 | People, dates, promises; technical update badges removed. |
| User control and freedom | 2 | 4 | Stable navigation; keyboard exits, Escape and history verified. |
| Consistency and standards | 2 | 3 | Shared primitives; profile containment and targets corrected. |
| Error prevention | 3 | 3 | Explicit source actions and consent, unchanged authority. |
| Recognition over recall | 3 | 3 | Person context and next reminder precede grouped tools. |
| Flexibility and efficiency | 3 | 3 | Pagination, compact filters, wide compositions and section links. |
| Aesthetic and minimalist design | 2 | 3 | Optional forms disclosed on intent; repeated empty panels reduced. |
| Error recovery | 3 | 3 | Spanish inline validation, section reopening and existing lifecycle tests. |
| Help and documentation | 3 | 3 | Source explanations and contextual consent retained. |
| **Total** | **27/40** | **31/40** | Stronger everyday experience; final score is parent synthesis. |

## Anti-pattern verdict
The shared shell, initials, dates and restrained moss/stone surfaces fit a personal
relationship tool. The main weakness was legacy profile sections with nested
containers and repeated empty descriptions, not a need for more decoration.
Assessment A observed that directly; the detector also flagged nested cards,
although most of its 40 occurrences were hidden, ordinary status elements or
legitimate privacy/action units. The fix flattened section wrappers and empty
setup while retaining real records and privacy boundaries.

The ERB directory CLI scan returned zero because its walker excludes ERB and
Ruby; that result was not accepted as a clean audit. Five rendered pages and
injected browser detection produced 52 flagged element groups / 59 rule
occurrences. The detector independently found the genuine reminder h2-to-h4
heading jump, now h3, and Turbo's default blue progress color, now moss.
System-font and overlay-shadow findings were false positives against this
product's documented design system; a visually hidden fieldset legend was not
a clipped popover. Raw evidence and interpretation are in assessment-b.md.
Overlays were captured in isolated browser screenshots. No live user-visible
overlay or browser tab remains open.

## Overall impression
Today now connects a person, real timing and a practical next action. People
starts with search and recognizable identities. Profiles keep essentials above
forms and make deeper capabilities addressable. The large-screen composition
uses distinct information columns rather than stretching paragraphs.

## What works
- One authorized navigation model serves both desktop and mobile, including
  nested forms, connection pages and administrator destinations.
- Scheduled obligations and optional ideas have separate hierarchy. Quiet days
  offer a helpful next step without fabricating urgency.
- Profile essentials and factual work context survive the shorter layout;
  source tools, consent, private records and deep links remain available.

## Priority findings and resolutions
1. **P1 — Focus behind the mobile menu.** Forward Tab previously reached covered
   page actions. The menu now closes when focus or a pointer leaves it, retaining
   the new focus; Escape returns focus to Menu. Both directions and locales pass.
   Command applied: impeccable harden.
2. **P2 — Generic profile section summaries.** A real next reminder/title/date or
   open promise now appears in Plans; the latest interaction includes its type.
   Duplicate section navigation appears only during expanded work.
   Command applied: impeccable distill.
3. **P2 — Nested profile panels and technical copy.** Outer utility-based panels
   are flattened, About emphasizes saved context plus one optional edit prompt,
   and Updates inline badges are removed. Reminder heading hierarchy is fixed.
   Command applied: impeccable polish.
4. **P2 — Small date and checkbox targets.** Add date uses the shared 44px action;
   suggested-field checkbox labels now have 44px clickable height.
   Command applied: impeccable adapt.
5. **P2 — Shared setup overwhelms existing spaces.** Family and partner creation
   use native disclosures, automatically open for validation errors, and keep
   consent/no-message explanations with their forms.
   Command applied: impeccable distill.

An additional parent browser check found a squeezed event-plan title at 1024px
despite zero overflow. Context now joins the task area at 62rem of container
width, and the local plan directory at 85rem; header actions wrap. The All event
plans route remains available at every width.

## Persona checks
- Keyboard users: forward/reverse Tab, Escape, skip link, native disclosures,
  Spanish validation and Turbo return paths checked.
- Returning mobile users: first person visible without scrolling, useful profile
  actions before forms, shared setup collapsed, no horizontal overflow.
- Users managing many relationships: 28-person test directory is paginated;
  1920/2560 layouts add useful agenda/ideas/context columns.

## Cognitive and emotional experience
The early experience is personal and calm. It shows people and chosen work
instead of a wall of tools or incomplete fields. Expanded tool sections remain
denser because they retain real capabilities and consent controls. Further
compression should preserve source evidence and deliberate decisions.

## Minor observations and future design questions
The wordmark wraps at 200% text on phone widths, with all content and Menu still
available. This is cosmetic rather than a lost-control issue. Empty About's
standalone heading was removed after the recheck. No invented relationship
scores, stock portraits or artificial activity were added.

For a future iteration: which existing source facts best help a returning person
choose their next action, and which optional inputs can appear closer to that
decision? No additional user clarification is required for this completed brief.

## Evidence
- assessment-a.md and assessment-b.md: independent initial reports and captures.
- final-review.md and final-a/: bilingual review, enlarged text and history.
- accessibility-final.md: contrast, targets, headings, motion and no-JS checks.
- ../matrix/, ../nested/, ../states/: routes, responsive compositions and
  deterministic busy/quiet/large-list states.
- ../acceptance.md: final goal evidence and validation boundaries.
