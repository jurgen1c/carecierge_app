# Carecierge Implementation Roadmap

## Suggested Epic Breakdown

### Epic 1: User Accounts and Onboarding

- User registration/login
- Basic onboarding
- Relationship type selection
- First relationship profile creation
- Initial important dates
- Initial preferences

### Epic 2: Relationship Profiles

- CRUD profiles
- Relationship types
- Profile templates
- Custom notes
- Contact methods
- Tags/groups
- Profile detail page

### Epic 3: Relationship Memory

- Preferences
- Likes/dislikes
- Desires/wants
- Boundaries
- Gift ideas
- Gift history
- Memory source tracking

### Epic 4: Important Dates and Reminders

- Important dates
- Recurring dates
- Reminder rules
- Notification preferences
- Reminder completion/snooze
- Daily/weekly notification digest

### Epic 5: Commitments and Follow-Ups

- Promise tracker
- Due dates
- Statuses
- Commitment reminders
- Relationship timeline integration

### Epic 6: Relationship Timeline

- Timeline model
- Timeline UI
- Manual entries
- Automatic entries from reminders, gifts, notes, and commitments
- Timeline filters

### Epic 7: Conversation Recaps and AI Extraction

- Conversation recap creation
- AI extraction jobs
- Extracted memories
- User approval flow
- Timeline integration
- Confidence/source tracking

### Epic 8: Relationship Search

- Structured search
- Profile search
- Preference search
- Date search
- Commitment search
- Natural language search later

### Epic 9: Daily Relationship Feed

- Feed item generation
- Upcoming dates
- Overdue commitments
- Suggested check-ins
- Suggested gestures
- Dismiss/snooze/complete actions

### Epic 10: Message Drafting Assistant

- Draft generation
- Tone selection
- Relationship-aware context
- Draft editing
- Save draft
- Copy/share draft

### Epic 11: Gift Recommendation

- Gift idea generation
- Preference-based suggestions
- Budget filters
- Gift history duplicate checks
- Save gift idea
- Mark gift purchased/given
- Reaction tracking

### Epic 12: Planning Framework

- Generic event plan model
- Plan tasks
- Budget
- Guest list
- Timeline
- Checklist
- Personal touch checklist
- Backup plan

### Epic 13: Birthday Concierge

- Birthday detection
- Birthday planning workflow
- Gift suggestions
- Celebration concepts
- Checklist generation
- Invitation draft
- Timeline generation

### Epic 14: Anniversary Concierge

- Anniversary detection
- Romantic plan suggestions
- Gift suggestions
- Date ideas
- Personal note prompts
- Checklist generation

### Epic 15: Vendor Discovery

- Vendor categories
- Vendor profiles
- Vendor search
- Vendor shortlist
- Vendor comparison
- Manual vendor entry
- Favorite vendors

### Epic 16: Booking and Quote Management

- Quote request draft
- Booking request
- Booking status
- Confirmation storage
- Deposit/payment reminders
- Cancellation policy tracking

### Epic 17: Approval Queue

- Approval request model
- Approval queue UI
- Approve/reject/edit/snooze
- Action execution after approval
- Audit logging

### Epic 18: Privacy and Permissions

- Privacy vault basics
- Sensitive notes
- Automation permissions
- AI processing permissions
- Data export
- Data deletion
- Audit log

### Epic 19: Integrations

- Calendar integration
- Contacts integration
- Email draft integration
- Push notifications
- Commerce integrations later

### Epic 20: Admin and Operations

- Admin dashboard
- Feature flags
- Vendor management
- AI feedback monitoring
- Background job monitoring
- Audit/event inspection

---

## Suggested MVP Scope

### MVP Goal

Validate that users want to store relationship memory and receive useful reminders, suggestions, and lightweight plans.

### MVP Should Include

1. User accounts
2. Relationship profiles
3. Relationship types/templates
4. Important dates
5. Preferences
6. Desires/wants
7. Gift ideas and gift history
8. Commitments/follow-ups
9. Reminder system
10. Relationship timeline
11. Conversation recaps
12. AI memory extraction with approval
13. Daily relationship feed
14. Message drafting assistant
15. Gift recommendations
16. Birthday concierge, lightweight
17. Planning checklist
18. Personal touch checklist
19. Privacy basics
20. Data export basics

### MVP Should Avoid

- Full marketplace
- Fully automated purchases
- Fully automated booking
- Automatic social media monitoring
- Auto-sending personal messages
- Shared couple/family spaces
- Complex vendor onboarding

---

## Recommended Phase Plan

### Phase 1: Relationship Memory Foundation

Build the core profile and memory system.

#### Features

- Profiles
- Relationship types
- Preferences
- Important dates
- Desires
- Notes
- Gift ideas
- Timeline

### Phase 2: Reminders and Follow-Through

Make the app actively useful.

#### Features

- Reminders
- Commitments
- Contact cadence
- Daily feed
- Notification preferences

### Phase 3: AI Assistance

Add intelligence.

#### Features

- Conversation recaps
- AI memory extraction
- Message drafting
- Gift recommendations
- Relationship persona
- Suggestion explanations

### Phase 4: Planning Workflows

Turn memory into action.

#### Features

- Birthday concierge
- Anniversary concierge
- Generic event planning
- Personal touch checklist
- Backup plans

### Phase 5: Human-in-the-Loop Automation

Begin execution while preserving control.

#### Features

- Approval queue
- Vendor shortlists
- Quote request drafts
- Booking request drafts
- Calendar integration
- Contacts integration

### Phase 6: Marketplace and Commerce

Add monetization and fulfillment.

#### Features

- Vendor marketplace
- Vendor accounts
- Booking integrations
- Gift purchasing
- Gift boxes
- Payments
- Concierge service tier

---

## Key System Concepts Engineering Should Consider

### Core Domain Models

- `User`
- `RelationshipProfile`
- `RelationshipType`
- `Preference`
- `Desire`
- `ImportantDate`
- `Reminder`
- `Commitment`
- `TimelineEntry`
- `ConversationRecap`
- `ExtractedMemory`
- `Gift`
- `GiftIdea`
- `EventPlan`
- `PlanTask`
- `Vendor`
- `VendorOption`
- `BookingRequest`
- `ApprovalRequest`
- `AuditLog`
- `AutomationRule`
- `NotificationPreference`

### Cross-Cutting Concerns

- Privacy and encryption
- AI source tracking
- Memory confidence
- User approval flows
- Background jobs
- Notifications
- Audit logging
- Data export/deletion
- Feature flags
- Permissions
- Search
- Event/timeline generation

### AI Design Requirements

AI should be used for:

- extraction
- summarization
- recommendations
- message drafting
- planning suggestions
- persona summaries
- search assistance

AI should not silently:

- send messages
- make purchases
- contact vendors
- update sensitive memory
- infer sensitive traits as facts
- make high-impact decisions without approval

### Automation Design Requirements

Automation should be permission-based and human-in-the-loop.

Automation levels could be modeled as:

1. Suggest only
2. Draft only
3. Prepare action for approval
4. Execute after approval
5. Execute automatically under explicit rule

Example:

Order flowers under $50 for anniversaries, but ask me to approve the card message.

---

## Product North Star

Carecierge should help users turn good intentions into thoughtful follow-through.

The app wins if users feel:

- I remember more.
- I forget fewer important things.
- I follow through better.
- I show up more thoughtfully.
- Planning meaningful gestures is easier.
- The app helps me care, but it does not pretend to care for me.
