---
name: Carecierge
description: A warm, trusted relationship-advisor product with restrained consumer clarity.
colors:
  canvas: "#ffffff"
  surface: "#fafaf9"
  private-line: "#e7e5e4"
  quiet-note: "#44403c"
  ink: "#0c0a09"
  primary: "#065f46"
  primary-hover: "#064e3b"
  danger-surface: "#fef2f2"
  danger-border: "#fca5a5"
  danger-ink: "#991b1b"
typography:
  headline:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.875rem"
    fontWeight: 600
    lineHeight: 1.2
  title:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 600
    lineHeight: 1.4
  body:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 600
    lineHeight: 1.25
rounded:
  control: "0.5rem"
  container: "0.75rem"
  section: "1rem"
spacing:
  xs: "0.5rem"
  sm: "0.75rem"
  md: "1rem"
  lg: "1.5rem"
  xl: "2rem"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.canvas}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0.75rem 1.25rem"
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
    textColor: "{colors.canvas}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0.75rem 1.25rem"
  button-danger:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.danger-ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "0.75rem 1.25rem"
---

# Design System: Carecierge

## 1. Overview

**Creative North Star: "The Trusted Concierge Desk"**

Carecierge should feel like the quiet desk in a well-run boutique hotel: warm, discreet, capable, human, and organized. The product is friendly and familiar, but it never turns relationship care into performance, surveillance, or sentimentality.

The system borrows the calm utility of Apple Reminders and Calendar, the consumer-trust clarity of Monzo and Revolut, and the service posture of a capable concierge who remembers context without making a show of it. The interface should make users feel prepared and supported, not watched, scored, or managed.

It explicitly rejects cold enterprise CRM language, clinical healthcare-portal sterility, surveillance-oriented AI assistant patterns, generic chatbot scaffolding, luxury-concierge theatrics, and overly romantic dating or couple-tracking aesthetics.

**Key Characteristics:**
- Quietly capable: useful before expressive.
- Warm but unsentimental: no hearts, pink gradients, or cheesy intimacy cues.
- Familiar controls: standard product patterns with strong trust and clear actions.
- Discreet guidance: automation is visible, explainable, and reversible.
- Human cadence: moments of choreography are earned, not constant.

## 2. Colors

The palette is restrained: true white and clean stone surfaces, deep readable ink, and one moss-green brand accent used sparingly for primary actions, active states, and moments of reassurance. A separate red family is semantic rather than decorative and is reserved for destructive actions and critical errors. The same values are exposed as Tailwind theme variables in `app/assets/stylesheets/application.tailwind.css`; new UI should consume those semantic tokens instead of introducing ticket-specific colors.

### Primary
- **Concierge Moss** (`#065f46`, `primary`): The primary brand accent. Use for primary actions, active navigation, confident confirmations, and advisor-like guidance. It should read botanical and grounded, not healthcare green or financial-success green.
- **Moss Hover** (`#064e3b`, `primary-hover`): Hover and active treatment for primary controls. Do not use it as a second decorative green.

### Semantic Danger
- **Danger Surface** (`#fef2f2`, `danger-surface`): Low-emphasis background for destructive confirmations and error summaries.
- **Danger Border** (`#fca5a5`, `danger-border`): Boundary for destructive controls and critical states.
- **Danger Ink** (`#991b1b`, `danger-ink`): High-contrast text and icons for destructive actions. Red is never a decorative secondary accent.

### Neutral
- **Clear Desk White** (`#ffffff`, `canvas`): Default content canvas. Keep it clean rather than cream, sand, beige, or parchment.
- **Soft Ledger Surface** (`#fafaf9`, `surface`): Page background, panels, and app-shell regions. It separates surfaces without making the UI feel card-heavy.
- **Trusted Ink** (`#0c0a09`, `ink`): Primary text. Body text must be high contrast and calm, never faint gray.
- **Quiet Note** (`#44403c`, `quiet-note`): Secondary text, helper copy, timestamps, and subdued labels.
- **Private Line** (`#e7e5e4`, `private-line`): Borders, dividers, form outlines, and inactive controls.

### Named Rules

**The Ten Percent Accent Rule.** Concierge Moss is rare by default. If more than 10% of a working screen is accented, the product starts to feel decorative instead of trustworthy.

**The Semantic Red Rule.** Red stays under 5% of a working screen and appears only for destructive actions, irreversible decisions, or critical errors. Informational warnings use neutral or context-appropriate treatments.

**The No Romance Palette Rule.** Pink gradients, heart-coded reds, and dating-app color cues are prohibited. Relationship care is treated as private life management, not romantic spectacle.

**The Clean Surface Rule.** Warmth comes from guidance, rhythm, and accent choices, not from beige body backgrounds.

## 3. Typography

**Display Font:** System sans (`ui-sans-serif, system-ui, sans-serif`)
**Body Font:** System sans (`ui-sans-serif, system-ui, sans-serif`)
**Label/Mono Font:** System sans; introduce mono only for a real data-heavy need.

**Character:** Typography should feel like a calm consumer productivity app: readable, rounded enough to feel approachable, precise enough to support trust. Use one well-tuned sans family before introducing any pairing.

### Hierarchy
- **Display**: Reserved for future marketing pages, onboarding moments, and major empty states. Product surfaces do not use oversized display type.
- **Headline** (600, `1.875rem`, 1.2): Page titles and primary workflow headings.
- **Title** (600, `1.25rem`, 1.4): Panel headings, section names, and card titles.
- **Body** (400, `1rem`, 1.5): Main content, guidance, relationship notes, and explanatory copy. Keep prose to 65-75ch where possible.
- **Label** (600, `0.875rem`, 1.25): Buttons, fields, metadata, navigation labels, and compact controls. Avoid loud uppercase tracking.

### Named Rules

**The Trusted Advisor Voice Rule.** Copy and type hierarchy should feel direct, kind, and specific. Never use vague emotional filler where a concrete next step would help.

**The Familiar Scale Rule.** Product UI uses fixed, practical type sizes. Fluid hero-scale type belongs only to future marketing surfaces.

## 4. Elevation

Carecierge is flat by default and layered only when structure or state requires it. Depth should come first from spacing, tonal surface shifts, and borders; shadows are reserved for overlays, menus, active drags, and focused work surfaces.

### Shadow Vocabulary
- **Resting surfaces:** No shadow by default; use `surface`, `canvas`, and `private-line` separation.
- **Interactive lift:** `0 1px 2px rgb(28 25 23 / 0.08)` for a hoverable panel only when the whole panel is an action target.
- **Overlay lift:** `0 10px 30px rgb(28 25 23 / 0.14)` for menus, dialogs, popovers, and live guidance surfaces.

### Named Rules

**The Discreet Depth Rule.** If the shadow is the first thing a user notices, it is too heavy.

**The Earned Ceremony Rule.** Core task transitions are restrained state changes. Choreography is allowed only for onboarding, recovery, and meaningful completion moments.

## 5. Components

Carecierge uses familiar Rails product UI primitives, with ViewComponent for reusable or stateful composition, Rails I18n for copy, Tailwind theme variables for semantic palette roles, and `StyleVariantsHelper` for component variants. New reusable UI should consume the documented semantic tokens rather than coupling its public meaning to a raw color name.

### Buttons
- **Shape:** Gently rounded, tactile, and stable (`rounded-lg`, `0.5rem`) with a 44px minimum target.
- **Primary:** `primary` fill with `canvas` text and `primary-hover` hover treatment, used for one main action per decision area.
- **Hover / Focus:** Subtle tonal shift, visible focus ring, no bounce or decorative motion.
- **Secondary / Ghost:** Quiet surface or transparent treatments for lower-priority actions.
- **Danger:** `canvas` or `danger-surface` with `danger-border` and `danger-ink`; never a solid red default unless the decision surface explicitly calls for maximum destructive emphasis.

### Cards / Containers
- **Corner Style:** `rounded-xl` (`0.75rem`) for containers and `rounded-2xl` (`1rem`) for major feature sections; never pill-like unless the control is a chip.
- **Background:** `canvas` or `surface`, not nested card stacks.
- **Shadow Strategy:** Flat at rest; use borders and spacing before shadows.
- **Internal Padding:** Use the documented spacing scale, normally `1rem` to `1.5rem`.

### Inputs / Fields
- **Style:** `canvas` background, `private-line` or the established stone-300 outline, readable placeholder text, `rounded-lg`, and a 44px minimum target.
- **Focus:** Visible `primary` ring or border shift without overwhelming the form.
- **Error / Disabled:** Explicit text and icon support; never rely on color alone.

### Navigation
- **Style:** Familiar app navigation with clear active states, calm labels, and restrained density.
- **Mobile Treatment:** Prioritize reachable primary actions, progressive disclosure, and predictable back paths.

### Rails ERB Templates
- **Template Style:** Use conventional Rails ERB templates with semantic HTML, Rails helpers, partials only for local one-off composition, and ViewComponent for reusable UI.
- **Copy:** User-facing text belongs in Rails I18n files, not hard-coded templates.
- **Forms:** Use Rails form helpers, explicit labels, accessible error output, and predictable Turbo-compatible markup.
- **Styling:** Keep styling in the project stylesheet or component styling layer; do not use inline styles.
- **Rendering Components:** Render ViewComponents through the `component` helper from `app/helpers/application_helper.rb` so ERB templates use the same concise component lookup pattern.

### ViewComponent Patterns
- **Reusable Components:** Buttons, cards, inputs, navigation elements, empty states, alerts, and recurring layout primitives should use the ViewComponent gem once they appear in more than one place or carry meaningful state.
- **Options:** Define component inputs with `dry-initializer` options, following the application component base pattern, instead of ad hoc initializer signatures.
- **Styles:** Define variantable component styles with `app/helpers/style_variants_helper.rb`; keep state and size variants in the style DSL rather than scattering class-string conditionals through templates.
- **Previews:** Reusable components should include Lookbook previews when practical so design review can happen without navigating full product flows.
- **Tests:** Component behavior, variants, and accessibility-relevant rendering should be covered with focused component specs.
- **Boundaries:** Keep component APIs small and semantic. Pass domain data or display values intentionally; do not make components reach across authorization, tenancy, or persistence boundaries.

## 6. Do's and Don'ts

### Do:
- **Do** use `$impeccable craft <new view or feature>` before building a new view so the design brief, layout, copy, responsive behavior, and implementation plan are shaped together.
- **Do** reuse the semantic palette in `app/assets/stylesheets/application.tailwind.css` and the machine-readable tokens in this file before considering any new color.
- **Do** use familiar product patterns from useful consumer tools like reminders, calendars, and banking apps.
- **Do** build reusable UI with ViewComponent and Rails ERB best practices instead of duplicating markup across templates.
- **Do** use `dry-initializer` for component options, `StyleVariantsHelper` for component styles, and the `component` helper for rendering components from ERB.
- **Do** keep primary actions clear, rare, and visually trustworthy.
- **Do** make automation explainable, reversible, and visibly in service of the user's intent.
- **Do** treat relationship data as sensitive through quiet states, clear permissions, and private-by-default interaction patterns.
- **Do** use choreography only when it helps a user understand progress, recovery, or completion.

### Don't:
- **Don't** make Carecierge feel like a cold enterprise CRM.
- **Don't** make it feel like a clinical healthcare portal.
- **Don't** make it feel like a surveillance-oriented AI assistant.
- **Don't** use generic chatbot scaffolding as the product's main visual metaphor.
- **Don't** use luxury concierge theatrics, gold-and-navy status cues, or hotel-service cliches.
- **Don't** use hearts, pink gradients, cheesy intimacy language, couple-tracking aesthetics, or anything that reads as relationship surveillance.
- **Don't** use red as a decorative accent; reserve `danger-*` tokens for destructive actions, irreversible decisions, and critical errors.
- **Don't** use side-stripe borders, gradient text, decorative glassmorphism, hero-metric templates, or repeated identical icon-card grids.
