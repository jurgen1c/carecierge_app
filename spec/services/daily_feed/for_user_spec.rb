require "rails_helper"

RSpec.describe DailyFeed::ForUser do
  it "builds a bounded, source-backed queue across every required feed item type" do
    now = ActiveSupport::TimeZone["America/Costa_Rica"].local(2026, 8, 14, 9)
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica", time_zone_configured: true)
    profile = create(:relationship_profile, user:, preferred_name: "Taylor")
    create(:relationship_preference, relationship_profile: profile, key: "Message style", value: "Brief", confidence: "confirmed")
    create(:reminder, user:, relationship_profile: profile, title: "Call Taylor", scheduled_at: now - 1.hour)
    create(:commitment, relationship_profile: profile, title: "Send the introduction", due_on: now.to_date - 1.day)
    create(:commitment, relationship_profile: profile, title: "Plan the weekend", due_on: now.to_date + 3.days)
    create(:important_date, relationship_profile: profile, title: "Taylor's birthday", starts_on: now.to_date + 2.days, recurrence: "none")
    create(:gift, relationship_profile: profile, name: "Photo book")
    draft = create(:message_draft, user:, relationship_profile: profile, updated_at: now - 1.day)
    create(:draft_revision, message_draft: draft, content: "Checking in about your new role.")
    create(:desire, relationship_profile: profile, title: "Walk together", category: "activity")

    result = Timecop.freeze(now) { described_class.call(user:, as_of: now) }

    expect(result.items.map(&:kind)).to include(
      "reminder",
      "commitment",
      "important_date",
      "gift",
      "message_draft",
      "plan_continuation",
      "relationship_goal",
      "suggestion"
    )
    expect(result.needs_attention.map(&:title)).to include("Call Taylor", "Send the introduction")
    expect(result.later_today.map(&:title)).to include("Photo book")
    expect(result.coming_up.map(&:title)).to include("Taylor's birthday", "Plan the weekend", "Walk together")
    expect(result.items).to all(satisfy { |item| item.source_label.present? && item.source_context.present? })
    expect(result.items.size).to be <= described_class::MAX_ITEMS
  end

  it "never includes another owner's or an archived relationship's sources" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    active_profile = create(:relationship_profile, user:)
    archived_profile = create(:relationship_profile, user:, discarded_at: now - 1.day)
    create(:reminder, user:, relationship_profile: active_profile, title: "Owned", scheduled_at: now)
    create(:gift, relationship_profile: archived_profile, name: "Archived")
    create(:reminder, title: "Other owner", scheduled_at: now)

    result = described_class.call(user:, as_of: now)

    expect(result.items.map(&:title)).to include("Owned")
    expect(result.items.map(&:title)).not_to include("Archived", "Other owner")
  end

  it "does not expose a foreign relationship through inconsistent owned reminder data" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    foreign_profile = create(:relationship_profile, preferred_name: "Private foreign name")
    reminder = create(:reminder, user:, title: "Owned reminder", notes: nil, scheduled_at: now)
    reminder.update_column(:relationship_profile_id, foreign_profile.id)

    item = described_class.call(user:, as_of: now).items.find { |candidate| candidate.source == reminder }

    expect(item.relationship_profile).to be_nil
    expect(item.detail).not_to include("Private foreign name")
  end

  it "uses the linked reminder instead of duplicating its commitment or important date" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile, due_on: now.to_date - 1.day)
    important_date = create(:important_date, relationship_profile: profile, starts_on: now.to_date, recurrence: "none")
    create(
      :reminder,
      user:,
      relationship_profile: profile,
      commitment:,
      important_date:,
      title: "One source-aware reminder",
      scheduled_at: now
    )

    result = described_class.call(user:, as_of: now)

    expect(result.items.count { |item| item.kind == "commitment" && item.source == commitment }).to eq(0)
    expect(result.items.count { |item| item.kind == "important_date" && item.source == important_date }).to eq(0)
    expect(result.items.count { |item| item.title == "One source-aware reminder" }).to eq(1)
  end

  it "keeps dispatched active reminders and their linked sources represented by the reminder" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile, due_on: now.to_date - 1.day)
    important_date = create(:important_date, relationship_profile: profile, starts_on: now.to_date, recurrence: "none")
    reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      commitment:,
      important_date:,
      title: "Dispatched but incomplete",
      scheduled_at: now - 1.hour
    )
    reminder.update_column(:next_delivery_at, nil)

    result = described_class.call(user:, as_of: now)

    expect(result.items.map(&:source)).to include(reminder)
    expect(result.items.map(&:source)).not_to include(commitment, important_date)
    expect(described_class.find(user:, item_key: "reminder:#{reminder.id}", as_of: now)&.source).to eq(reminder)
  end

  it "does not reveal a linked commitment or important date when its reminder is hidden" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile, due_on: now.to_date - 1.day)
    important_date = create(:important_date, relationship_profile: profile, starts_on: now.to_date, recurrence: "none")
    reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      commitment:,
      important_date:,
      title: "Hidden linked reminder",
      scheduled_at: now
    )
    create(:feed_item_state, user:, item_key: "reminder:#{reminder.id}", dismissed_at: now)

    result = described_class.call(user:, as_of: now)

    expect(result.items.map(&:source)).not_to include(reminder, commitment, important_date)
  end

  it "filters dismissed and currently snoozed items without losing expired snoozes" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    dismissed = create(:reminder, user:, relationship_profile: profile, title: "Dismissed", scheduled_at: now)
    snoozed = create(:reminder, user:, relationship_profile: profile, title: "Snoozed", scheduled_at: now)
    expired = create(:reminder, user:, relationship_profile: profile, title: "Back again", scheduled_at: now)
    create(:feed_item_state, user:, item_key: "reminder:#{dismissed.id}", dismissed_at: now)
    create(:feed_item_state, user:, item_key: "reminder:#{snoozed.id}", dismissed_at: nil, snoozed_until: now + 1.day)
    create(:feed_item_state, user:, item_key: "reminder:#{expired.id}", dismissed_at: nil, snoozed_until: now - 1.minute)

    result = described_class.call(user:, as_of: now)

    expect(result.items.map(&:title)).to include("Back again")
    expect(result.items.map(&:title)).not_to include("Dismissed", "Snoozed")
    expect(described_class.call(user:, as_of: now, include_hidden: true).items.map(&:title)).to include("Dismissed", "Snoozed")
  end

  it "fills each section from visible reminders after applying feed state" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    reminders = 101.times.map do |index|
      create(
        :reminder,
        user:,
        relationship_profile: profile,
        title: format("Reminder %03d", index),
        scheduled_at: now + index.minutes
      )
    end
    timestamps = { created_at: now, updated_at: now }
    FeedItemState.insert_all!(
      reminders.first(100).map do |reminder|
        timestamps.merge(
          id: SecureRandom.uuid,
          user_id: user.id,
          item_key: "reminder:#{reminder.id}",
          dismissed_at: now,
          snoozed_until: nil
        )
      end
    )

    result = described_class.call(user:, as_of: now)

    expect(result.later_today.map(&:title)).to include("Reminder 100")
  end

  it "bounds reminders with the same case-insensitive title ordering as the final queue" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    %w[Bravo Charlie Delta Echo Foxtrot Golf Hotel Zulu apple].each do |title|
      create(:reminder, user:, relationship_profile: profile, title:, scheduled_at: now)
    end

    queries = capture_selects { @result = described_class.call(user:, as_of: now) }
    reminder_query = queries.find { |sql| sql.include?('FROM "reminders"') && sql.include?("LIMIT") }

    expect(@result.needs_attention.map(&:title)).to include("apple")
    expect(@result.needs_attention.map(&:title)).not_to include("Zulu")
    expect(reminder_query).to include('lower(reminders.title)')
  end

  it "keeps commitment visibility state stable as a plan becomes due" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile, title: "Plan the visit", due_on: Date.new(2026, 8, 16))
    create(:feed_item_state, user:, item_key: "commitment:#{commitment.id}", dismissed_at: Time.zone.local(2026, 8, 14, 9))

    future_result = described_class.call(user:, as_of: Time.zone.local(2026, 8, 14, 9), include_hidden: true)
    due_result = described_class.call(user:, as_of: Time.zone.local(2026, 8, 16, 9), include_hidden: true)

    expect(future_result.find("commitment:#{commitment.id}")).to have_attributes(kind: "plan_continuation")
    expect(due_result.find("commitment:#{commitment.id}")).to have_attributes(kind: "commitment")
    expect(described_class.call(user:, as_of: Time.zone.local(2026, 8, 16, 9)).items).to be_empty
  end

  it "prefers a visible high-impact suggestion and falls back after feed-only dismissal" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Taylor")
    create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Message style",
      value: "Brief",
      confidence: "confirmed"
    )
    create(:mood_note, relationship_profile: profile, observed_at: now - 1.day)

    high_impact_item = described_class.call(user:, as_of: now).items.find { |item| item.kind == "suggestion" }

    expect(high_impact_item.suggestion.suggestion_type).to eq("repair_focused")

    create(:feed_item_state, user:, item_key: high_impact_item.key, dismissed_at: now)
    fallback_item = described_class.call(user:, as_of: now).items.find { |item| item.kind == "suggestion" }

    expect(fallback_item.suggestion.suggestion_type).to eq("message")
  end

  it "preserves inferred certainty on suggestion source context" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:relationship_preference, relationship_profile: profile, confidence: "inferred")

    suggestion_item = described_class.call(user:).items.find { |item| item.kind == "suggestion" }

    expect(suggestion_item.source_certainty).to eq("inferred")
  end

  it "includes a spontaneous gesture grounded in a recent interaction" do
    now = Time.zone.local(2026, 8, 19, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    interaction = create(:interaction, relationship_profile: profile, occurred_at: now - 2.days)

    gesture_item = described_class.call(user:, as_of: now).items
      .find { |item| item.suggestion&.gesture? }

    expect(gesture_item).to be_present
    expect(gesture_item.suggestion.reasons.sole.source).to eq(interaction)
  end

  it "loads only the current message draft revision for each profile" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile, situation: "Continue the conversation")
    create(:draft_revision, message_draft: draft, position: 1, content: "Earlier private draft")
    create(:draft_revision, message_draft: draft, position: 2, content: "Current private draft")

    queries = capture_selects do
      @draft_item = described_class.call(user:).items.find { |item| item.kind == "message_draft" }
    end
    revision_query = queries.grep(/FROM "draft_revisions"/).sole

    expect(revision_query).to include("DISTINCT ON")
    expect(@draft_item.source_context).to eq("Current private draft")
  end

  it "fails closed when a message draft ownership column disagrees with its profile owner" do
    user = create(:user)
    other_user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    create(:draft_revision, message_draft: draft, content: "Private draft from another account")
    draft.update_column(:user_id, other_user.id)

    result = described_class.call(user:)

    expect(result.items.map(&:key)).not_to include("message_draft:#{draft.id}")
    expect(described_class.find(user:, item_key: "message_draft:#{draft.id}")).to be_nil
  end

  it "evaluates priorities across every active profile before applying section limits" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    50.times do |index|
      create(:relationship_profile, user:, first_name: format("A%02d", index), last_name: "Person")
    end
    final_profile = create(:relationship_profile, user:, first_name: "Zulu", last_name: "Person")
    create(:commitment, relationship_profile: final_profile, title: "Overdue priority", due_on: now.to_date - 1.day)

    result = described_class.call(user:, as_of: now)

    expect(result.needs_attention.map(&:title)).to include("Overdue priority")
  end

  it "bounds commitment and important-date candidates independently by feed section" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    8.times do |index|
      create(:commitment, relationship_profile: profile, title: "Overdue #{index}", due_on: now.to_date - 1.day)
      create(:important_date, relationship_profile: profile, title: "Today #{index}", starts_on: now.to_date, recurrence: "none")
    end
    create(:commitment, relationship_profile: profile, title: "Future commitment", due_on: now.to_date + 3.days)
    create(:important_date, relationship_profile: profile, title: "Future date", starts_on: now.to_date + 4.days, recurrence: "none")

    result = described_class.call(user:, as_of: now)

    expect(result.coming_up.map(&:title)).to include("Future commitment", "Future date")
  end

  it "ranks unscheduled commitments before post-horizon plans when bounding candidates" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    8.times do |index|
      create(
        :commitment,
        relationship_profile: profile,
        title: "Post-horizon plan #{index}",
        due_on: now.to_date + (31 + index).days
      )
    end
    create(:commitment, relationship_profile: profile, title: "Unscheduled priority", due_on: nil)

    result = described_class.call(user:, as_of: now)

    expect(result.coming_up.map(&:title)).to include("Unscheduled priority")
  end

  it "uses localized display titles when bounding untitled important dates" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    titled_dates = 8.times.map do |index|
      create(
        :important_date,
        relationship_profile: profile,
        title: "Antes #{index}",
        notes: "Contexto",
        starts_on: now.to_date + 1.day,
        recurrence: "none"
      )
    end
    untitled_date = create(
      :important_date,
      relationship_profile: profile,
      title: nil,
      date_type: "birthday",
      notes: "Contexto",
      starts_on: now.to_date + 1.day,
      recurrence: "none"
    )

    result = I18n.with_locale(:es) { described_class.call(user:, as_of: now) }
    important_dates = result.coming_up.select { |item| item.kind == "important_date" }
    canonical_event = I18n.with_locale(:es) do
      Suggestions::ForProfile.call(relationship_profile: profile, as_of: now)
        .find { |suggestion| suggestion.suggestion_type == "event" }
    end
    feed_event = result.items.find { |item| item.suggestion&.suggestion_type == "event" }

    expect(important_dates.map(&:source)).to contain_exactly(*titled_dates)
    expect(feed_event.source).to eq(untitled_date)
    expect(feed_event.suggestion.fingerprint).to eq(canonical_event.fingerprint)
  end

  it "does not add per-profile queries while assembling suggestion sources" do
    one_profile_user = user_with_profiles(1)
    five_profile_user = user_with_profiles(5)

    one_profile_queries = capture_selects { described_class.call(user: one_profile_user.reload) }
    five_profile_queries = capture_selects { described_class.call(user: five_profile_user.reload) }

    expect(five_profile_queries.size - one_profile_queries.size).to be <= 2
  end

  it "batches last-interaction timestamps for contact cadence suggestions" do
    user = create(:user)
    5.times do |index|
      profile = create(:relationship_profile, user:)
      create(:contact_cadence, relationship_profile: profile, created_at: 10.days.ago)
      create(:interaction, relationship_profile: profile, occurred_at: index.days.ago)
    end

    queries = capture_selects { described_class.call(user:) }

    expect(queries.grep(/MAX\("interactions"\."occurred_at"\)/).size).to be <= 1
  end

  it "preserves the canonical protected-memory suggestion when candidate sources are bounded" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    8.times do |index|
      memory = create(
        :memory_record,
        id: format("00000000-0000-0000-0000-%012d", index + 1),
        relationship_profile: profile,
        title: "Memory #{index + 1}"
      )
      PrivacyVault::Protect.call(actor: user, protectable: memory).update!(suggestion_usage: "allowed")
    end
    canonical = create(
      :memory_record,
      id: "ffffffff-ffff-ffff-ffff-ffffffffffff",
      relationship_profile: profile,
      title: "A canonical first memory"
    )
    PrivacyVault::Protect.call(actor: user, protectable: canonical).update!(suggestion_usage: "allowed")

    canonical_message = Suggestions::ForProfile.call(relationship_profile: profile, as_of: now)
      .find { |suggestion| suggestion.suggestion_type == "message" }
    feed_message = described_class.call(user:, as_of: now).items
      .find { |item| item.suggestion&.suggestion_type == "message" }

    expect(feed_message.suggestion.fingerprint).to eq(canonical_message.fingerprint)
  end

  it "keeps bounded suggestion candidates identical to canonical action resolution" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, type: "RelationshipProfiles::Colleague")
    canonical_desire = create(:desire, relationship_profile: profile, category: "gift", title: "A first gift")
    create(:desire, relationship_profile: profile, category: "gift", title: "Z fallback gift")
    create(:feed_item_state, user:, item_key: "relationship_goal:#{canonical_desire.id}", dismissed_at: now)
    canonical_date = create(:important_date, relationship_profile: profile, starts_on: now.to_date + 1.day, recurrence: "none")
    create(:important_date, relationship_profile: profile, starts_on: now.to_date + 2.days, recurrence: "none")
    canonical_commitment = create(:commitment, relationship_profile: profile, due_on: now.to_date - 2.days, title: "A first follow-up")
    create(:commitment, relationship_profile: profile, due_on: now.to_date - 1.day, title: "Z fallback follow-up")
    create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
    create(:reminder, user:, relationship_profile: profile, important_date: canonical_date, scheduled_at: now)
    create(:reminder, user:, relationship_profile: profile, commitment: canonical_commitment, scheduled_at: now)

    canonical = Suggestions::ForProfile.call(relationship_profile: profile, as_of: now).index_by(&:suggestion_type)
    service = described_class.new(user:, as_of: now, include_hidden: false)
    bounded = service.send(:suggestions_by_profile).values.sole.index_by(&:suggestion_type)

    expect(bounded.fetch("message").fingerprint).to eq(canonical.fetch("message").fingerprint)
    expect(bounded.keys).not_to include("gift", "event", "professional_follow_up")
  end

  it "does not instantiate ineligible historical profile sources" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:commitment, relationship_profile: profile, status: "completed", completed_at: now - 1.year)
    create(:important_date, relationship_profile: profile, recurrence: "none", starts_on: now.to_date - 1.year)
    create(:gift, relationship_profile: profile, status: "given", given_on: now.to_date - 1.year)
    create(:desire, relationship_profile: profile, status: "fulfilled")
    archived_memory = create(:memory_record, relationship_profile: profile, status: "archived")
    create(:privacy_vault_item, relationship_profile: profile, protectable: archived_memory)
    create(:social_context_note, relationship_profile: profile, allow_suggestions: false)
    create(:mood_note, relationship_profile: profile, observed_at: now - 1.year)

    instantiated = capture_instantiations { described_class.call(user:, as_of: now) }

    expect(instantiated.values_at(
      "Commitment",
      "ImportantDate",
      "Gift",
      "Desire",
      "MemoryRecord",
      "PrivacyVaultItem",
      "SocialContextNote",
      "MoodNote"
    )).to all(eq(0))
  end

  it "bounds eligible source records per active profile before instantiation" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    12.times do |index|
      create(:gift, relationship_profile: profile, name: format("Gift %02d", index))
      create(:desire, relationship_profile: profile, title: format("Goal %02d", index))
      create(:commitment, relationship_profile: profile, title: format("Plan %02d", index), due_on: now.to_date + index.days)
      create(:relationship_preference, relationship_profile: profile, key: format("Preference %02d", index))
      create(:memory_record, relationship_profile: profile, title: format("Memory %02d", index))
    end

    12.times do |index|
      create(:interaction, relationship_profile: profile, occurred_at: now - index.minutes)
    end

    instantiated = capture_instantiations { described_class.call(user:, as_of: now) }

    expect(instantiated.values_at("Gift", "Desire", "RelationshipPreference", "MemoryRecord"))
      .to all(be <= described_class::SECTION_LIMIT)
    expect(instantiated["Interaction"]).to be <= 10
    expect(instantiated["Commitment"]).to be <= described_class::MAX_ITEMS
  end

  it "scopes ranked source candidates to the current owner's active profiles" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    other_profile = create(:relationship_profile)
    service = described_class.new(user:, as_of: Time.zone.local(2026, 8, 14, 9), include_hidden: false)

    service.send(:profiles)
    sql = service.send(:gift_candidate_scope).to_sql

    expect(sql).to include(profile.id)
    expect(sql).not_to include(other_profile.id)
  end

  it "finds one hidden source item without instantiating the owner's full feed" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    gifts = 25.times.map do |index|
      create(:gift, relationship_profile: profile, name: format("Gift %02d", index))
    end
    target = gifts.last
    create(:feed_item_state, user:, item_key: "gift:#{target.id}", dismissed_at: now)

    instantiated = capture_instantiations do
      @found_item = described_class.find(user:, item_key: "gift:#{target.id}", as_of: now)
    end

    expect(@found_item).to have_attributes(key: "gift:#{target.id}", source: target)
    expect(instantiated["Gift"]).to eq(1)
  end

  it "resolves every feed item key through an owner-scoped targeted lookup" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:relationship_preference, relationship_profile: profile, key: "Message style", value: "Brief")
    create(:reminder, user:, relationship_profile: profile, scheduled_at: now)
    create(:commitment, relationship_profile: profile, due_on: now.to_date)
    create(:important_date, relationship_profile: profile, starts_on: now.to_date, recurrence: "none")
    create(:gift, relationship_profile: profile)
    draft = create(:message_draft, user:, relationship_profile: profile)
    create(:draft_revision, message_draft: draft)
    create(:desire, relationship_profile: profile)

    items = described_class.call(user:, as_of: now).items.index_by(&:kind)

    %w[reminder commitment important_date gift message_draft relationship_goal suggestion].each do |kind|
      item = items.fetch(kind)
      expect(described_class.find(user:, item_key: item.key, as_of: now)).to have_attributes(
        key: item.key,
        kind:
      )
    end

    other_user = create(:user)
    other_reminder = create(:reminder, user: other_user, scheduled_at: now)
    expect(described_class.find(user:, item_key: "reminder:#{other_reminder.id}", as_of: now)).to be_nil
  end

  it "applies source visibility state before candidate limits" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:)
    gifts = 9.times.map do |index|
      create(:gift, relationship_profile: profile, name: format("Gift %02d", index), updated_at: now + index.minutes)
    end
    gifts.first(8).each do |gift|
      create(:feed_item_state, user:, item_key: "gift:#{gift.id}", dismissed_at: now)
    end

    result = described_class.call(user:, as_of: now)

    expect(result.later_today.map(&:title)).to include("Gift 08")
    expect(described_class.find(user:, item_key: "gift:#{gifts.last.id}", as_of: now)).to be_present
  end

  def user_with_profiles(count)
    create(:user).tap do |user|
      count.times do |index|
        profile = create(:relationship_profile, user:, preferred_name: "Person #{index}")
        create(:relationship_preference, relationship_profile: profile, key: "Interest #{index}", value: "Walking")
      end
    end
  end

  def capture_selects
    queries = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"
      next unless payload[:sql].start_with?("SELECT")

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end

  def capture_instantiations
    counts = Hash.new(0)
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      counts[payload[:class_name]] += payload[:record_count]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "instantiation.active_record") { yield }
    counts
  end
end
