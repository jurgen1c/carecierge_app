---
id: relationship_profiles.gift_boxes_are_private_manual_bundles_with_conservative_companion_suggestions
type: fact
system: relationship_profiles
status: current
confidence: high
severity: critical
title: Gift boxes are private manual bundles with conservative companion suggestions
claim: >
  Active profile owners assemble encrypted gift boxes for an explicit occasion,
  with exact decimal budgets and up to thirty encrypted item records. Items
  retain independent manual purchase and readiness states, named vendors, safe
  HTTP(S) purchase links and optional costs. Unknown costs are excluded from
  the labeled known total. Account-to-profile locks and a mandatory box revision
  serialize writes, including item-only edits. Local companion ideas use only
  confirmed positive preferences; any negative preference, constraint, allergy,
  boundary or cultural constraint withholds ideas for manual review, as do box
  constraints and exhausted budgets. Ideas have no verified prices, exclude
  existing localized companion names, access no notes or vault sources and
  never call a provider or purchase anything. Delivery links prefill a private
  reminder using an owner-scoped box ID and the owner's time zone; viewing
  creates no reminder and later box edits do not reschedule saved reminders.
  EN/ES views use no-store and disable Turbo snapshots. Box parameters are
  filtered from logs, owner exports include items and profile deletion cascades.
source_files:
  - app/models/gift_box.rb
  - app/models/gift_box_item.rb
  - app/models/relationship_profile.rb
  - app/controllers/gift_boxes_controller.rb
  - app/controllers/reminders_controller.rb
  - app/policies/gift_box_policy.rb
  - app/services/gift_boxes/companions.rb
  - app/views/components/gift_box_workspace_component.rb
  - app/views/components/gift_box_workspace_component.html.erb
  - app/views/gift_boxes/index.html.erb
  - app/views/gift_boxes/show.html.erb
  - app/views/relationship_profiles/show.html.erb
  - app/serializers/data_exports/snapshot.rb
  - config/routes.rb
  - config/initializers/filter_parameter_logging.rb
  - config/locales/gift_boxes.en.yml
  - config/locales/gift_boxes.es.yml
  - db/migrate/20260905114943_create_gift_boxes.rb
  - db/schema.rb
related_files:
  - spec/requests/gift_boxes_spec.rb
  - spec/models/gift_box_spec.rb
  - spec/services/gift_boxes/companions_spec.rb
  - spec/system/gift_boxes_spec.rb
  - spec/serializers/data_exports/gift_box_snapshot_spec.rb
symbols:
  - GiftBox
  - GiftBoxItem
  - GiftBoxes::Companions
  - GiftBoxesController
routes:
  - relationship_profile_gift_boxes
  - relationship_profile_gift_box
tags: [gifts, gift_boxes, privacy, review_only, budget]
verification:
  - bundle exec rspec spec/requests/gift_boxes_spec.rb spec/models/gift_box_spec.rb spec/services/gift_boxes spec/system/gift_boxes_spec.rb spec/serializers/data_exports/gift_box_snapshot_spec.rb
  - bundle exec rspec
  - bin/ci
last_verified_commit: null
---

# Gift boxes are private manual bundles with conservative companion suggestions

Suggestions are local, conservative planning hints. Their presence never establishes
suitability, available stock, price or permission to act externally. Migration adds
only new UUID tables, indexed foreign keys and cascading deletion; rollback removes
those tables and their data. Existing tables are not rewritten.
