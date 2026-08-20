---
id: daily_feed.concierge_queue_is_derived_and_owner_scoped
type: fact
system: daily_feed
status: current
confidence: verified
severity: critical

title: The Concierge Queue is derived, owner-scoped, and source-authoritative

claim: >
  The dashboard derives a bounded Concierge Queue only from the authenticated
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
  can ground spontaneous gestures.

source_files:
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
  - app/views/components/daily_feed_item_component.rb
  - app/views/components/daily_feed_item_component.html.erb
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
  - DailyFeed::ForUser
  - DailyFeed::Item
  - DailyFeed::Result
  - DailyFeedItemComponent
  - FeedItemState
  - FeedItemStatePolicy
  - FeedItemsController

routes:
  - dashboard
  - dismiss_feed_item
  - snooze_feed_item

tags:
  - daily_feed
  - dashboard
  - concierge_queue
  - owner_scope

verification:
  - bundle exec rspec spec/models/feed_item_state_spec.rb spec/services/daily_feed/for_user_spec.rb spec/components/daily_feed_item_component_spec.rb spec/requests/daily_feed_spec.rb spec/requests/data_controls_spec.rb spec/system/daily_feed_spec.rb
  - bin/rubocop
  - bin/memory validate
  - bin/memory coverage --git-diff
  - bin/memory audit --git-diff
  - bin/ci

last_verified_commit: 05aec403efdcb51bff5689047fa3f3a8cf66c318
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

- `bundle exec rspec spec/models/feed_item_state_spec.rb spec/services/daily_feed/for_user_spec.rb spec/components/daily_feed_item_component_spec.rb spec/requests/daily_feed_spec.rb spec/requests/data_controls_spec.rb spec/system/daily_feed_spec.rb`
- `bin/rubocop`
- `bin/memory validate`
- `bin/memory coverage --git-diff`
- `bin/memory audit --git-diff`
- `bin/ci`
