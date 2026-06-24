<!-- SEED: re-run /impeccable document once there's code to capture the actual tokens and components. -->
---
name: Carecierge
description: A warm, trusted relationship-advisor product with restrained consumer clarity.
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

The palette should be restrained: mostly true white or clean near-white surfaces, deep readable ink, and one moss-green brand accent used sparingly for primary actions, active states, and moments of reassurance. The final token values are [to be resolved during implementation].

### Primary
- **Concierge Moss** ([to be resolved during implementation]): The primary brand accent. Use for primary actions, active navigation, confident confirmations, and advisor-like guidance. It should read botanical and grounded, not healthcare green or financial-success green.

### Secondary
- **Discreet Terracotta** ([to be resolved during implementation]): Optional secondary warmth for small supportive cues, illustrations, or selected empty-state details. Use only when the moss accent needs a human counterpoint.

### Neutral
- **Clear Desk White** ([to be resolved during implementation]): Default page background. Keep it clean rather than cream, sand, beige, or parchment.
- **Soft Ledger Surface** ([to be resolved during implementation]): Panels, cards, and app-shell regions. It should separate surfaces without making the UI feel card-heavy.
- **Trusted Ink** ([to be resolved during implementation]): Primary text. Body text must be high contrast and calm, never faint gray.
- **Quiet Note** ([to be resolved during implementation]): Secondary text, helper copy, timestamps, and subdued labels. It must remain readable.
- **Private Line** ([to be resolved during implementation]): Borders, dividers, form outlines, and inactive controls.

### Named Rules

**The Ten Percent Accent Rule.** Concierge Moss is rare by default. If more than 10% of a working screen is accented, the product starts to feel decorative instead of trustworthy.

**The No Romance Palette Rule.** Pink gradients, heart-coded reds, and dating-app color cues are prohibited. Relationship care is treated as private life management, not romantic spectacle.

**The Clean Surface Rule.** Warmth comes from guidance, rhythm, and accent choices, not from beige body backgrounds.

## 3. Typography

**Display Font:** [single warm sans family to be chosen at implementation]
**Body Font:** [same warm sans family to be chosen at implementation]
**Label/Mono Font:** [optional; choose only if data-heavy workflows need it]

**Character:** Typography should feel like a calm consumer productivity app: readable, rounded enough to feel approachable, precise enough to support trust. Use one well-tuned sans family before introducing any pairing.

### Hierarchy
- **Display** ([to be resolved during implementation]): Reserved for marketing pages, onboarding moments, and major empty states. Avoid oversized product headings.
- **Headline** ([to be resolved during implementation]): Page titles and primary workflow headings.
- **Title** ([to be resolved during implementation]): Panel headings, section names, and card titles.
- **Body** ([to be resolved during implementation]): Main content, guidance, relationship notes, and explanatory copy. Keep prose to 65-75ch where possible.
- **Label** ([to be resolved during implementation]): Buttons, fields, metadata, navigation labels, and compact controls. Avoid loud uppercase tracking.

### Named Rules

**The Trusted Advisor Voice Rule.** Copy and type hierarchy should feel direct, kind, and specific. Never use vague emotional filler where a concrete next step would help.

**The Familiar Scale Rule.** Product UI uses fixed, practical type sizes. Fluid hero-scale type belongs only to future marketing surfaces.

## 4. Elevation

Carecierge is flat by default and layered only when structure or state requires it. Depth should come first from spacing, tonal surface shifts, and borders; shadows are reserved for overlays, menus, active drags, and focused work surfaces.

### Shadow Vocabulary
- **Resting surfaces** ([to be resolved during implementation]): No shadow by default; use surface color and border separation.
- **Interactive lift** ([to be resolved during implementation]): A very soft shadow for hoverable panels only when the panel is a clear action target.
- **Overlay lift** ([to be resolved during implementation]): Menus, dialogs, popovers, and live guidance surfaces.

### Named Rules

**The Discreet Depth Rule.** If the shadow is the first thing a user notices, it is too heavy.

**The Earned Ceremony Rule.** Core task transitions are restrained state changes. Choreography is allowed only for onboarding, recovery, and meaningful completion moments.

## 5. Components

No component library exists yet. Initial components should be familiar Rails product UI primitives built with ViewComponent where reusable, localized with Rails I18n, and styled through the project stylesheet rather than inline styles. New reusable UI should be extracted into ViewComponent classes instead of duplicated across ERB templates.

### Buttons
- **Shape:** Gently rounded, tactile, and stable ([exact radius to be resolved during implementation]).
- **Primary:** Concierge Moss fill with high-contrast text, used for one main action per decision area.
- **Hover / Focus:** Subtle tonal shift, visible focus ring, no bounce or decorative motion.
- **Secondary / Ghost:** Quiet surface or transparent treatments for lower-priority actions.

### Cards / Containers
- **Corner Style:** Modest radius, never pill-like unless the control is a chip.
- **Background:** White or Soft Ledger Surface, not nested card stacks.
- **Shadow Strategy:** Flat at rest; use borders and spacing before shadows.
- **Internal Padding:** Comfortable enough for personal context, compact enough for repeated workflows.

### Inputs / Fields
- **Style:** Clear outline, readable placeholder text, generous tap targets.
- **Focus:** Visible ring or border shift using Concierge Moss without overwhelming the form.
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
- **Don't** use side-stripe borders, gradient text, decorative glassmorphism, hero-metric templates, or repeated identical icon-card grids.
