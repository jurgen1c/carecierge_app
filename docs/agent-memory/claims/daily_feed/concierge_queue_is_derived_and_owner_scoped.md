---
id: daily_feed.concierge_queue_is_derived_and_owner_scoped
type: fact
system: daily_feed
status: current
confidence: high
severity: critical

title: The Concierge Queue is derived, owner-scoped, and source-authoritative

claim: >
  The Today dashboard derives a bounded feed only from the authenticated
  user's active reminders and relationship sources. Reminder bounds use effective
  scheduled-or-snoozed delivery time rather than dispatch reservation state.
  Priorities span every active relationship before independent section limits
  apply. Owner-scoped, visibility-aware SQL bounds mirror final item ordering;
  event-suggestion bounds instead retain the canonical suggestion service's
  source ordering. Hidden linked
  work cannot reappear under another key, and hidden suggestions fall through only
  to eligible canonical replacements. Items retain source context, source-owned
  lifecycles, and visible certainty evidence. The private queue disables Turbo
  snapshots and bounds eager loading. FeedItemState persists only dismissal or
  snooze presentation state while locking the account and then the source, so
  deletion races cannot leave orphaned state. Source cleanup occurs only after
  source SQL deletion, including every variant-aware spontaneous-gesture key
  derived from that source. Snooze returns at 9:00 AM the next day in the user's
  notification time zone. Feed state is exported with the account, pruned with
  permanently deleted sources or relationships, and cascades on account deletion.
  Recent interaction candidates are bounded per active relationship before they
  can ground spontaneous gestures. Today separates needs_attention, later_today, coming_up and optional ideas, with
  eight visible items per section. SQL candidate bounds partition undated promises separately from dated upcoming commitments. Future dated promises remain upcoming;
  undated promises, drafts, goals, gift ideas and suggestions remain optional.
  Today::Overview adds up to four active event plans over the next 30 owner-local
  days with an uncapped matching total, up to four due saved contact rhythms,
  active people count, and eligible persisted pending-review count. Overview
  reads do not synchronize or mutate approval requests. Shared navigation links
  to each source workspace without mixing its lifecycle into feed state.

source_files:
  - app/queries/today/overview.rb
  - app/controllers/dashboard_controller.rb
  - app/controllers/feed_items_controller.rb
  - app/models/concerns/feed_item_state_source.rb
  - app/models/contact_cadence.rb
  - app/models/feed_item_state.rb
  - app/models/interaction.rb
  - app/models/relationship_persona.rb
  - app/models/suggestion.rb
  - app/services/daily_feed/for_user.rb
  - app/views/dashboard/index.html.erb
  - db/migrate/20260814160000_create_feed_item_states.rb

related_files:
  - app/models/commitment.rb
  - app/models/desire.rb
  - app/models/gift.rb
  - app/models/important_date.rb
  - app/models/memory_record.rb
  - app/models/message_draft.rb
  - app/models/mood_note.rb
  - app/models/relationship_profile.rb
  - app/models/relationship_preference.rb
  - app/models/reminder.rb
  - app/models/social_context_note.rb
  - app/policies/feed_item_state_policy.rb
  - app/serializers/data_exports/snapshot.rb
  - app/services/daily_feed/item.rb
  - app/services/daily_feed/result.rb
  - app/services/suggestions/for_profile.rb
  - app/controllers/approval_requests_controller.rb
  - app/views/components/daily_feed_item_component.rb
  - app/views/components/daily_feed_item_component.html.erb
  - config/locales/today.en.yml
  - config/locales/today.es.yml
  - spec/queries/today/overview_spec.rb
  - config/locales/daily_feed.en.yml
  - config/locales/daily_feed.es.yml
  - config/routes.rb
  - docs/features/05-01-daily-relationship-feed.md
  - spec/components/daily_feed_item_component_spec.rb
  - spec/models/feed_item_state_spec.rb
  - spec/requests/daily_feed_spec.rb
  - spec/services/daily_feed/for_user_spec.rb
  - spec/system/daily_feed_spec.rb

symbols:
  - Today::Overview
  - DailyFeed::ForUser
  - DailyFeed::Item
  - DailyFeed::Result
  - DailyFeedItemComponent
  - FeedItemState
  - FeedItemStatePolicy
  - FeedItemsController

routes:
  - dashboard
  - approvals
  - vendors
  - dismiss_feed_item
  - snooze_feed_item

tags:
  - daily_feed
  - dashboard
  - concierge_queue
  - owner_scope

verification:
  - bundle exec rspec spec/queries/today/overview_spec.rb spec/models/feed_item_state_spec.rb spec/services/daily_feed/for_user_spec.rb spec/components/daily_feed_item_component_spec.rb spec/requests/daily_feed_spec.rb spec/requests/data_controls_spec.rb spec/system/daily_feed_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: null
---

# The Concierge Queue is derived, owner-scoped, and source-authoritative

## Claim

The dashboard presents priority sections assembled from existing owner-scoped
relationship data. Items keep source context and source-owned actions. The only
new persistence is dismissal or snooze visibility state, which never mutates the
source lifecycle and is pruned with permanent source, relationship, or account
deletion.

Candidate bounds preserve independent section capacity and final direct-item
ordering. Event-suggestion bounds preserve canonical suggestion source ordering.
Active reminders remain queued by effective scheduled-or-snoozed delivery time
after their delivery reservation is claimed.
Approval work and the saved-vendor catalog remain separate owner-scoped
destinations linked from both dashboard navigation variants rather than derived
feed item lifecycles.
Visibility writes lock the account and then source through persistence so account
deletion uses the same order and source-deletion races cannot leave orphaned state.

## Why It Matters

The feed aggregates several sensitive systems. Deriving it through the current
user, excluding archived relationships, and preserving source authority avoids
cross-owner exposure and conflicting lifecycle state while keeping the daily
experience actionable.

## Evidence

- `app/services/daily_feed/for_user.rb`
- `app/controllers/feed_items_controller.rb`
- `app/models/concerns/feed_item_state_source.rb`
- `app/models/contact_cadence.rb`
- `app/models/feed_item_state.rb`
- `app/views/dashboard/index.html.erb`
- `spec/services/daily_feed/for_user_spec.rb`
- `spec/requests/daily_feed_spec.rb`

## Verification

- `bundle exec rspec spec/queries/today/overview_spec.rb spec/models/feed_item_state_spec.rb spec/services/daily_feed/for_user_spec.rb spec/components/daily_feed_item_component_spec.rb spec/requests/daily_feed_spec.rb spec/requests/data_controls_spec.rb spec/system/daily_feed_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`

## Today composition

Scheduled obligations and optional ideas have independent bounded sections. Owner-local upcoming plans and saved contact rhythms are previews, not new source records. The review number counts persisted eligible pending requests; opening Reviews can discover newly eligible work through its existing synchronization.
