# Carecierge Jira Implementation Order

This document defines the recommended implementation order for CAR Jira tickets.
It is dependency-based, not board-rank metadata. Use it to rank the CAR board,
plan milestones, and decide whether a new ticket should be pulled forward or
held for a later phase.

## Ordering Principles

- Build durable relationship memory before AI, planning, marketplace, or shared
  collaboration features.
- Ship the smallest useful loop early: create a relationship, capture memory,
  remember dates and commitments, and surface useful follow-through.
- Put trust controls in place before automation touches external systems or
  sensitive relationship data.
- Keep post-MVP integrations, marketplace, commerce, and shared spaces behind
  feature flags until the core product is stable.
- Every ticket should keep referencing its source feature file from
  `docs/features`.

## Epic Order

| Order | Epic | Why it comes here |
| --- | --- | --- |
| 1 | CAR-1 User Accounts and Onboarding | Entry path and first value moment. |
| 2 | CAR-2 Relationship Profiles | Core object every later feature references. |
| 3 | CAR-3 Relationship Memory | Preferences, desires, gifts, and source-backed facts. |
| 4 | CAR-4 Important Dates and Reminders | Turns memory into timely usefulness. |
| 5 | CAR-5 Commitments and Follow-Ups | Adds the follow-through loop. |
| 6 | CAR-6 Relationship Timeline | Creates a durable history backbone. |
| 7 | CAR-18 Privacy and Permissions | Trust baseline before deeper AI and automation. |
| 8 | CAR-7 Conversation Recaps and AI Extraction | AI memory only after source/confidence and approval rules exist. |
| 9 | CAR-8 Relationship Search | Becomes valuable once enough memory exists. |
| 10 | CAR-9 Daily Relationship Feed | Pulls reminders, commitments, dates, and suggestions into a home surface. |
| 11 | CAR-10 Message Drafting Assistant | Uses profile and memory context while keeping user control. |
| 12 | CAR-11 Gift Recommendation | Builds on preferences, desires, gift history, and dates. |
| 13 | CAR-12 Planning Framework | General planning primitives before concierge workflows. |
| 14 | CAR-13 Birthday Concierge | First flagship concierge workflow. |
| 15 | CAR-14 Anniversary Concierge | Reuses planning and gift foundations. |
| 16 | CAR-81 Notifications | Preference and digest polish after reminders/feed exist. |
| 17 | CAR-17 Approval Queue | Human-in-the-loop automation control surface. |
| 18 | CAR-15 Vendor Discovery | Vendor data after plans and approval concepts are clear. |
| 19 | CAR-16 Booking and Quote Management | Execution support after vendor discovery. |
| 20 | CAR-19 Integrations | External systems after privacy, approvals, and core objects. |
| 21 | CAR-20 Admin and Operations | Operational controls once feature surfaces exist. |
| 22 | CAR-77 Collaboration Modes | Shared spaces last because authorization and privacy complexity is high. |

## Phase 0: Delivery Controls

Goal: make the app safe to roll out incrementally before the feature surface
expands.

1. CAR-21 Implement user registration and login
2. CAR-76 Add feature flags for staged rollout

Exit criteria:

- Users can register, sign in, and sign out.
- New capabilities can be guarded by feature flags.
- Feature flag decisions are testable and visible to authorized operators.

## Phase 1: Relationship Profile Foundation

Goal: users can create the core relationship object and complete a useful first
run.

1. CAR-27 Build relationship profiles
2. CAR-28 Create relationship type templates
3. CAR-29 Add relationship tags and segments
4. CAR-30 Store preferences, likes, dislikes, and constraints
5. CAR-35 Track important dates and milestones
6. CAR-22 Build basic onboarding flow
7. CAR-23 Support relationship type selection during onboarding
8. CAR-24 Create first relationship profile from onboarding
9. CAR-25 Capture initial important dates in onboarding
10. CAR-26 Capture initial preferences in onboarding

Exit criteria:

- A signed-in user can create a first relationship profile.
- The first profile can include relationship type, tags, preferences, and
  important dates.
- Onboarding can be skipped or resumed without blocking core use.

## Phase 2: Relationship Memory Backbone

Goal: store the memory that later reminders, search, AI, gifts, and plans need.

1. CAR-31 Track desires, wants, and future ideas
2. CAR-32 Track gift history
3. CAR-33 Track memory confidence and source
4. CAR-41 Build relationship timeline
5. CAR-42 Capture conversation recaps
6. CAR-34 Record sentiment and mood notes

Exit criteria:

- Memory records have source and confidence where needed.
- Timeline entries can link back to their source objects.
- Conversation recaps and mood notes can enrich the relationship history without
  making diagnostic claims.

## Phase 3: Reminders and Follow-Through

Goal: make Carecierge actively useful before adding heavy AI or marketplace
work.

1. CAR-36 Build reusable reminder system
2. CAR-39 Track promises and commitments
3. CAR-40 Track contact cadence and stale relationships
4. CAR-37 Implement notification preferences
5. CAR-38 Build daily and weekly notification digest

Exit criteria:

- Reminders support dates, commitments, and cadence.
- Notification preferences and digests respect user control.
- Follow-through language stays supportive and non-mechanical.

## Phase 4: Trust and Safety Baseline

Goal: establish privacy, permission, audit, and portability foundations before
AI starts making high-value suggestions.

1. CAR-67 Build privacy vault for sensitive records
2. CAR-68 Define permission-based automation rules
3. CAR-69 Record audit logs for important actions
4. CAR-70 Export and delete user data

Exit criteria:

- Sensitive records can be protected and excluded from automation where needed.
- Automation has explicit permission boundaries.
- Important actions can be audited.
- Users have a basic export/delete path.

## Phase 5: AI Assistance Foundation

Goal: add intelligence while keeping extracted memories and suggestions
source-backed and user-controlled.

1. CAR-43 Extract and approve AI memory
2. CAR-44 Build relationship persona summaries
3. CAR-49 Build suggestion engine with explanations
4. CAR-45 Build relationship memory search
5. CAR-50 Draft relationship-aware messages
6. CAR-51 Suggest responses to messages and situations
7. CAR-52 Analyze user-provided social context

Exit criteria:

- AI-generated memory requires user approval before becoming canonical.
- Suggestions explain why they appear.
- Drafting assists users but never auto-sends personal messages.
- Search can identify source records and relationships.

## Phase 6: Daily Experience

Goal: make the app feel like a trusted daily relationship advisor by gathering
the right next actions into one calm surface.

1. CAR-46 Build daily relationship feed
2. CAR-47 Generate relationship briefings
3. CAR-48 Suggest spontaneous gestures

Exit criteria:

- Feed items can be dismissed, snoozed, completed, or acted on.
- Briefings distinguish confirmed facts from inferred context.
- Gesture suggestions are practical, explainable, and respectful.

## Phase 7: Gift and Planning MVP

Goal: turn relationship memory into thoughtful plans and gifts without external
commerce automation.

1. CAR-53 Recommend gifts from relationship memory
2. CAR-56 Build generic event planning assistant
3. CAR-57 Build personal touch checklist
4. CAR-58 Generate backup plans for events
5. CAR-59 Build birthday concierge workflow
6. CAR-60 Build anniversary concierge workflow

Exit criteria:

- Gift recommendations use preferences, constraints, dates, and gift history.
- Event plans can hold tasks, reminders, notes, gifts, drafts, and backups.
- Birthday and anniversary workflows reuse the generic planning model.

## Phase 8: Human-in-the-Loop Execution

Goal: prepare for external action while preserving approval and user control.

1. CAR-66 Build approval queue
2. CAR-61 Discover and save vendors
3. CAR-62 Compare vendor shortlists
4. CAR-65 Collect and compare vendor quotes
5. CAR-64 Manage reservations and booking status

Exit criteria:

- High-impact actions can enter a review queue.
- Vendor and quote data can be tracked manually before integrations exist.
- Bookings and reservations can be represented without automated booking.

## Phase 9: Post-MVP Commerce, Integrations, and Operations

Goal: add external connectivity and operational visibility after core product
behavior is stable.

1. CAR-71 Integrate calendars
2. CAR-72 Integrate contacts
3. CAR-73 Integrate email and messaging workflows
4. CAR-54 Assist gift purchases without auto-buying
5. CAR-55 Build custom gift box builder
6. CAR-63 Model local marketplace foundations
7. CAR-74 Integrate commerce and booking providers
8. CAR-75 Build admin dashboard

Exit criteria:

- External connections are permission-gated and revocable.
- Commerce and booking integrations do not bypass approval rules.
- Admin tools do not expose sensitive relationship content unnecessarily.

## Phase 10: Collaboration Modes

Goal: add shared relationship planning only after the privacy and permission
model has proven stable.

1. CAR-78 Build shared couple space
2. CAR-79 Build family mode
3. CAR-80 Build professional relationship mode

Exit criteria:

- Shared spaces require explicit invitation and acceptance.
- Private notes remain private unless explicitly shared.
- Relationship modes reuse core profiles, memory, reminders, briefings, and
  drafting without weakening privacy boundaries.

## MVP Cut Line

The recommended MVP ends after Phase 7, with CAR-66 from Phase 8 pulled in if
AI extraction or any high-impact suggestion is enabled for real users.

MVP includes:

- CAR-21 through CAR-43 where they support accounts, onboarding, profiles,
  memory, dates, reminders, timeline, privacy, and AI extraction.
- CAR-44, CAR-45, CAR-46, CAR-47, CAR-48, CAR-49, CAR-50, and CAR-51 for the
  first AI-assisted daily experience.
- CAR-53, CAR-56, CAR-57, CAR-58, CAR-59, and CAR-60 for gift and planning
  workflows.
- CAR-67 through CAR-70 as trust foundations.
- CAR-76 for staged rollout.

Post-MVP by default:

- CAR-52 social context automation beyond user-provided notes.
- CAR-54, CAR-55, CAR-61 through CAR-65, and CAR-71 through CAR-75.
- CAR-78 through CAR-80 collaboration modes.

## Pull-Forward Rules

Use these rules when choosing the next ticket:

- Pull trust/safety tickets forward when a feature would otherwise process
  sensitive data, run AI, contact external systems, or change user-visible
  memory without review.
- Pull feature flags forward before any feature that should be hidden from
  general users.
- Pull notification preferences forward before any feature sends recurring
  user-facing reminders or digests.
- Pull approval queue forward before vendor, commerce, booking, message-send,
  or automation execution work.
- Do not pull collaboration modes forward until private versus shared ownership
  rules are implemented and tested.
