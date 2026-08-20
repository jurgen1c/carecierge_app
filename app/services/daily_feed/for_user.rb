module DailyFeed
  class ForUser
    SECTION_LIMIT = 8
    MAX_ITEMS = SECTION_LIMIT * 3
    UPCOMING_DAYS = 30
    REMINDER_EFFECTIVE_DELIVERY_SQL = "COALESCE(reminders.snoozed_until, reminders.scheduled_at)"

    SECTION_ORDER = {
      "needs_attention" => 0,
      "later_today" => 1,
      "coming_up" => 2
    }.freeze

    def self.call(user:, as_of: Time.current, include_hidden: false)
      new(user:, as_of:, include_hidden:).call
    end

    def self.find(user:, item_key:, as_of: Time.current)
      new(user:, as_of:, include_hidden: true).find(item_key)
    end

    def initialize(user:, as_of:, include_hidden:)
      @user = user
      @as_of = as_of
      @include_hidden = include_hidden
      time_zone_name = user.notification_preference&.time_zone.presence
      @zone = time_zone_name ? ActiveSupport::TimeZone[time_zone_name] : Time.zone
      @local_now = as_of.in_time_zone(zone)
    end

    def call
      items = raw_items
      items = reject_hidden(items) unless include_hidden
      grouped = items.group_by(&:section)

      Result.new(
        needs_attention: sort(grouped.fetch("needs_attention", [])).first(SECTION_LIMIT),
        later_today: sort(grouped.fetch("later_today", [])).first(SECTION_LIMIT),
        coming_up: sort(grouped.fetch("coming_up", [])).first(SECTION_LIMIT)
      )
    end

    def find(item_key)
      item_type, identifier = item_key.to_s.split(":", 2)

      case item_type
      when "reminder" then find_reminder_item(identifier)
      when "commitment" then find_commitment_item(identifier)
      when "important_date" then find_important_date_item(identifier)
      when "gift" then find_gift_item(identifier)
      when "message_draft" then find_message_draft_item(identifier)
      when "relationship_goal" then find_relationship_goal_item(identifier)
      when "suggestion" then find_suggestion_item(identifier)
      end
    end

    private

    attr_reader :user, :as_of, :include_hidden, :zone, :local_now

    def raw_items
      reminder_items + profile_source_items + suggestion_items
    end

    def reminder_items
      reminders.map { |reminder| reminder_item(reminder) }
    end

    def reminder_item(reminder)
      delivery_at = reminder.effective_delivery_at
      profile = active_profile(reminder.relationship_profile)
      section = if delivery_at <= as_of
        "needs_attention"
      elsif delivery_at.in_time_zone(zone).to_date == local_now.to_date
        "later_today"
      else
        "coming_up"
      end

      build_item(
        key: "reminder:#{reminder.id}",
        kind: "reminder",
        section:,
        title: reminder.title,
        detail: reminder.notes.presence || relationship_name(profile),
        source_label: source_label("reminder"),
        source_context: reminder.notes.presence || reminder.reminder_type_label,
        source: reminder,
        relationship_profile: profile,
        sort_at: delivery_at,
        action_kind: "complete_reminder"
      )
    end

    def profile_source_items
      profiles.flat_map do |profile|
        commitment_items(profile) + important_date_items(profile) + gift_items(profile) +
          message_draft_items(profile) + relationship_goal_items(profile)
      end
    end

    def commitment_items(profile)
      profile.commitments.filter_map { |commitment| commitment_item(profile, commitment) }
    end

    def commitment_item(profile, commitment, suppress_linked: true)
      return unless commitment.open?
      return if suppress_linked && linked_commitment_ids.include?(commitment.id)

      if commitment.due_on.present? && commitment.due_on < local_now.to_date
        kind = "commitment"
        section = "needs_attention"
        action_kind = "complete_commitment"
      elsif commitment.due_on == local_now.to_date
        kind = "commitment"
        section = "later_today"
        action_kind = "complete_commitment"
      else
        kind = "plan_continuation"
        section = "coming_up"
        action_kind = "edit_commitment"
      end

      build_item(
        key: "commitment:#{commitment.id}",
        kind:,
        section:,
        title: commitment.title,
        detail: commitment.notes.presence || relationship_name(profile),
        source_label: source_label(kind),
        source_context: commitment.notes.presence || due_context(commitment.due_on),
        source: commitment,
        relationship_profile: profile,
        sort_at: time_for_date(commitment.due_on || upcoming_end.to_date),
        action_kind:
      )
    end

    def important_date_items(profile)
      profile.important_dates.filter_map { |important_date| important_date_item(profile, important_date) }
    end

    def important_date_item(profile, important_date, suppress_linked: true)
      return if suppress_linked && linked_important_date_ids.include?(important_date.id)

      occurrence = important_date.next_occurrence_on(as_of: local_now.to_date)
      return unless occurrence && occurrence <= upcoming_end.to_date

      build_item(
        key: "important_date:#{important_date.id}",
        kind: "important_date",
        section: occurrence == local_now.to_date ? "later_today" : "coming_up",
        title: important_date.display_title,
        detail: I18n.t("daily_feed.items.important_date.detail", name: relationship_name(profile)),
        source_label: source_label("important_date"),
        source_context: important_date.notes.presence || I18n.l(occurrence, format: :long),
        source: important_date,
        relationship_profile: profile,
        sort_at: time_for_date(occurrence),
        action_kind: "plan_important_date"
      )
    end

    def gift_items(profile)
      profile.gifts.filter_map { |gift| gift_item(profile, gift) }
    end

    def gift_item(profile, gift)
      return unless gift.status.in?(Gift::EDITABLE_STATUSES)

      build_item(
        key: "gift:#{gift.id}",
        kind: "gift",
        section: "later_today",
        title: gift.name,
        detail: gift.occasion.presence || relationship_name(profile),
        source_label: source_label("gift"),
        source_context: gift.notes.presence || gift.status_label,
        source: gift,
        relationship_profile: profile,
        sort_at: gift.updated_at,
        action_kind: "edit_gift"
      )
    end

    def message_draft_items(profile)
      draft = profile.message_draft
      revision = current_draft_revisions[draft&.id]
      item = message_draft_item(profile, draft, revision)
      item ? [ item ] : []
    end

    def message_draft_item(profile, draft, revision)
      return unless draft && revision

      build_item(
        key: "message_draft:#{draft.id}",
        kind: "message_draft",
        section: "later_today",
        title: I18n.t("daily_feed.items.message_draft.title", name: relationship_name(profile)),
        detail: draft.situation.presence || revision.content.truncate(120),
        source_label: source_label("message_draft"),
        source_context: revision.content.truncate(200),
        source: draft,
        relationship_profile: profile,
        sort_at: draft.updated_at,
        action_kind: "open_message_draft"
      )
    end

    def relationship_goal_items(profile)
      profile.desires.filter_map { |desire| relationship_goal_item(profile, desire) }
    end

    def relationship_goal_item(profile, desire)
      return unless desire.status.in?(Desire::EDITABLE_STATUSES)

      build_item(
        key: "relationship_goal:#{desire.id}",
        kind: "relationship_goal",
        section: "coming_up",
        title: desire.title,
        detail: relationship_name(profile),
        source_label: source_label("relationship_goal"),
        source_context: desire.notes.presence || desire.category_label,
        source: desire,
        relationship_profile: profile,
        sort_at: time_for_date(desire.captured_on || local_now.to_date),
        action_kind: "edit_relationship_goal"
      )
    end

    def suggestion_items
      suggestions_by_profile.filter_map do |profile, suggestions|
        suggestion = prioritized_visible_suggestions(profile, suggestions).first
        next unless suggestion

        suggestion_item(profile, suggestion)
      end
    end

    def prioritized_visible_suggestions(profile, suggestions)
      suggestions
        .reject { |suggestion| suggestion_feedbacks[suggestion.fingerprint]&.hidden? }
        .reject { |suggestion| suggestion_feed_state_hidden?(profile, suggestion) }
        .sort_by do |suggestion|
          [ suggestion.high_impact? ? 0 : 1, Suggestions::ForProfile::TYPE_ORDER.fetch(suggestion.suggestion_type) ]
        end
    end

    def suggestion_item(profile, suggestion)
      build_item(
        key: suggestion_item_key(profile, suggestion),
        kind: "suggestion",
        section: suggestion.high_impact? ? "needs_attention" : "later_today",
        title: suggestion.title,
        detail: suggestion.detail,
        source_label: source_label("suggestion"),
        source_context: suggestion.reasons.map(&:evidence).join(" · "),
        source_certainty: suggestion.certainty,
        source: suggestion.reasons.first.source,
        relationship_profile: profile,
        sort_at: as_of,
        action_kind: "act_on_suggestion",
        suggestion:
      )
    end

    def build_item(suggestion: nil, source_certainty: nil, **attributes)
      Item.new(**attributes, source_certainty:, suggestion:)
    end

    def find_reminder_item(identifier)
      reminder = user.reminders.active
        .includes(:relationship_profile, :important_date, :commitment)
        .where("#{REMINDER_EFFECTIVE_DELIVERY_SQL} <= ?", upcoming_end)
        .find_by(id: identifier)
      reminder_item(reminder) if reminder
    end

    def find_commitment_item(identifier)
      commitment = owner_profile_source(Commitment, identifier)
      return unless commitment&.open?
      return if linked_source_reminders.where(commitment_id: commitment.id).exists?

      commitment_item(commitment.relationship_profile, commitment, suppress_linked: false)
    end

    def find_important_date_item(identifier)
      important_date = owner_profile_source(ImportantDate, identifier)
      return unless important_date
      return if linked_source_reminders.where(important_date_id: important_date.id).exists?

      important_date_item(important_date.relationship_profile, important_date, suppress_linked: false)
    end

    def find_gift_item(identifier)
      gift = owner_profile_source(Gift, identifier)
      gift_item(gift.relationship_profile, gift) if gift
    end

    def find_message_draft_item(identifier)
      draft = owner_profile_source(MessageDraft.where(user_id: user.id), identifier)
      return unless draft

      revision = draft.draft_revisions.order(position: :desc).first
      message_draft_item(draft.relationship_profile, draft, revision)
    end

    def find_relationship_goal_item(identifier)
      desire = owner_profile_source(Desire, identifier)
      relationship_goal_item(desire.relationship_profile, desire) if desire
    end

    def find_suggestion_item(identifier)
      profile_id, fingerprint = identifier.to_s.split(":", 2)
      return if profile_id.blank? || fingerprint.blank?

      profile = user.relationship_profiles.active.find_by(id: profile_id)
      return unless profile

      preload_profile_sources([ profile ])
      candidates = suggestions_for_profile(profile)
      source_states = suggestion_source_states(candidates)
      suggestion = eligible_source_suggestions(candidates, source_states:).find do |candidate|
        candidate.fingerprint == fingerprint
      end
      return unless suggestion
      return if user.suggestion_feedbacks.find_by(fingerprint:)&.hidden?

      suggestion_item(profile, suggestion)
    end

    def owner_profile_source(model, identifier)
      model
        .joins(:relationship_profile)
        .merge(user.relationship_profiles.active)
        .includes(:relationship_profile)
        .find_by(id: identifier)
    end

    def profiles
      @profiles ||= user.relationship_profiles.active.ordered.to_a.tap do |records|
        preload_profile_sources(records)
      end
    end

    def current_draft_revisions
      @current_draft_revisions ||= DraftRevision
        .select("DISTINCT ON (message_draft_id) draft_revisions.*")
        .where(message_draft_id: profiles.filter_map { |profile| profile.message_draft&.id })
        .order(:message_draft_id, position: :desc)
        .index_by(&:message_draft_id)
    end

    def reminders
      @reminders ||= begin
        scope = user.reminders.active
          .includes(:relationship_profile, :important_date, :commitment)
          .where("#{REMINDER_EFFECTIVE_DELIVERY_SQL} <= ?", upcoming_end)
          .order(Arel.sql("#{REMINDER_EFFECTIVE_DELIVERY_SQL} ASC, lower(reminders.title) ASC, reminders.id ASC"))

        visible_scope = include_hidden ? scope : scope.where(visible_reminder_sql, user.id, as_of)
        [
          visible_scope.where("#{REMINDER_EFFECTIVE_DELIVERY_SQL} <= ?", as_of).limit(SECTION_LIMIT),
          visible_scope
            .where("#{REMINDER_EFFECTIVE_DELIVERY_SQL} > ? AND #{REMINDER_EFFECTIVE_DELIVERY_SQL} <= ?", as_of, local_now.end_of_day)
            .limit(SECTION_LIMIT),
          visible_scope.where("#{REMINDER_EFFECTIVE_DELIVERY_SQL} > ?", local_now.end_of_day).limit(SECTION_LIMIT)
        ].flat_map(&:to_a)
      end
    end

    def preload_profile_sources(records)
      @active_profile_ids = records.map(&:id)
      preload_profile_association(records, :important_dates, important_date_candidate_scope)
      preload_profile_association(records, :gifts, gift_candidate_scope)
      preload_profile_association(records, :desires, desire_candidate_scope)
      preload_profile_association(records, :commitments, commitment_candidate_scope)
      preload_profile_association(records, :contact_cadence)
      preload_cadence_last_interactions(records)
      preload_profile_association(records, :interactions, interaction_candidate_scope)
      preload_profile_association(records, :mood_notes, mood_note_candidate_scope)
      preload_profile_association(records, :relationship_preferences, preference_candidate_scope)
      preload_profile_association(records, :memory_records, eligible_memory_scope)
      preload_profile_association(records, :privacy_vault_items, eligible_vault_item_scope)
      preload_profile_association(records, :social_context_notes, social_context_candidate_scope)
      preload_profile_association(records, :message_draft, MessageDraft.where(user_id: user.id))
    end

    def preload_profile_association(records, association, scope = nil)
      ActiveRecord::Associations::Preloader.new(records:, associations: association, scope:).call
    end

    def preload_cadence_last_interactions(records)
      last_interactions = Interaction
        .where(relationship_profile_id: active_profile_ids)
        .group(:relationship_profile_id)
        .maximum(:occurred_at)
      records.each do |profile|
        profile.contact_cadence&.preload_last_interaction_at(last_interactions[profile.id])
      end
    end

    def important_date_candidate_scope
      occurrence = Arel.sql(important_date_occurrence_sql)
      date_type = ImportantDate.arel_table[:date_type]
      scope = ImportantDate.where(occurrence.not_eq(nil))
      direct_candidates = bounded_candidate_scope(
        scope.where.not(id: linked_important_date_ids),
        order_sql: important_date_candidate_order_sql,
        partition_sql: important_date_section_partition_sql,
        state_prefix: "important_date"
      )
      suggestion_candidates = bounded_candidate_scope(
        scope.where(date_type.not_eq("appointment").or(occurrence.lteq(local_now.to_date + 7.days))),
        order_sql: important_date_suggestion_candidate_order_sql,
        limit: 1
      )

      direct_candidates.or(suggestion_candidates)
    end

    def gift_candidate_scope
      bounded_candidate_scope(
        Gift.where(status: Gift::EDITABLE_STATUSES),
        order_sql: "gifts.updated_at ASC, lower(gifts.name) ASC, gifts.id ASC",
        state_prefix: "gift"
      )
    end

    def desire_candidate_scope
      scope = Desire.where(status: Desire::EDITABLE_STATUSES)
      direct_candidates = bounded_candidate_scope(
        scope,
        order_sql: "desires.captured_on ASC NULLS LAST, lower(desires.title) ASC, desires.id ASC",
        state_prefix: "relationship_goal"
      )
      suggestion_candidates = bounded_candidate_scope(
        scope,
        order_sql: "CASE desires.status WHEN 'active' THEN 0 ELSE 1 END, lower(desires.title) ASC, desires.id ASC",
        partition_sql: "desires.relationship_profile_id, desires.category",
        limit: 1
      )

      direct_candidates.or(suggestion_candidates)
    end

    def commitment_candidate_scope
      scope = Commitment.where(status: "open")
      direct_candidates = bounded_candidate_scope(
        scope.where.not(id: linked_commitment_ids),
        order_sql: commitment_candidate_order_sql,
        partition_sql: commitment_section_partition_sql,
        state_prefix: "commitment"
      )
      suggestion_candidates = bounded_candidate_scope(
        scope.where(due_on: ...local_now.to_date),
        order_sql: "commitments.due_on ASC, lower(commitments.title) ASC, commitments.id ASC",
        limit: 1
      )

      direct_candidates.or(suggestion_candidates)
    end

    def mood_note_candidate_scope
      bounded_candidate_scope(
        MoodNote.where(category: Suggestions::ForProfile::REPAIR_CATEGORIES, observed_at: (as_of - 30.days)..as_of),
        order_sql: "mood_notes.observed_at DESC, mood_notes.id DESC",
        limit: 1
      )
    end

    def interaction_candidate_scope
      bounded_candidate_scope(
        Interaction.where(occurred_at: (as_of - 30.days)..as_of),
        order_sql: "interactions.occurred_at DESC, interactions.id DESC",
        limit: 10
      )
    end

    def preference_candidate_scope
      bounded_candidate_scope(
        RelationshipPreference.all,
        order_sql: <<~SQL.squish
          CASE relationship_preferences.confidence WHEN 'confirmed' THEN 0 ELSE 1 END,
          lower(relationship_preferences.key) ASC,
          relationship_preferences.id ASC
        SQL
      )
    end

    def eligible_memory_scope
      eligible_unprotected_memory_scope.or(eligible_protected_memory_scope)
    end

    def eligible_unprotected_memory_scope
      scope = MemoryRecord
        .where.missing(:privacy_vault_item)
        .where(status: RelationshipPersona::INCLUDED_MEMORY_STATUSES)
        .where("memory_records.stale_after IS NULL OR memory_records.stale_after >= ?", Date.current)

      bounded_candidate_scope(
        scope,
        order_sql: <<~SQL.squish
          CASE
            WHEN memory_records.source IN ('user_confirmed', 'user_corrected') THEN 0
            WHEN memory_records.source = 'ai_inferred' THEN 1
            WHEN memory_records.confidence = 'confirmed' THEN 0
            ELSE 1
          END,
          lower(memory_records.title) ASC,
          memory_records.id ASC
        SQL
      )
    end

    def eligible_protected_memory_scope
      scope = MemoryRecord
        .joins(:privacy_vault_item)
        .where(status: RelationshipPersona::INCLUDED_MEMORY_STATUSES)
        .where("memory_records.stale_after IS NULL OR memory_records.stale_after >= ?", Date.current)
        .where(privacy_vault_items: { suggestion_usage: "allowed" })

      bounded_candidate_scope(
        scope,
        order_sql: "privacy_vault_items.protected_at DESC, privacy_vault_items.id DESC",
        limit: RelationshipPersona::SUGGESTION_SOURCE_LIMIT
      )
    end

    def eligible_vault_item_scope
      PrivacyVaultItem.where(relationship_profile_id: active_profile_ids).where(
        protectable_type: "MemoryRecord",
        protectable_id: eligible_memory_scope.select(:id)
      )
    end

    def social_context_candidate_scope
      bounded_candidate_scope(
        SocialContextNote.where(allow_suggestions: true),
        order_sql: "social_context_notes.created_at DESC, social_context_notes.id DESC",
        limit: SocialContextNote::DOWNSTREAM_SOURCE_LIMIT
      ).with_rich_text_body
    end

    def bounded_candidate_scope(scope, order_sql:, partition_sql: nil, limit: SECTION_LIMIT, state_prefix: nil)
      model = scope.model
      table_name = model.table_name
      partition_sql ||= "#{table_name}.relationship_profile_id"
      scope = scope.where(relationship_profile_id: active_profile_ids)
      if state_prefix && !include_hidden
        scope = scope.where(visible_source_sql(table_name, state_prefix), user.id, as_of)
      end
      ranked = scope.reorder(nil).select(
        "#{table_name}.id",
        "ROW_NUMBER() OVER (PARTITION BY #{partition_sql} ORDER BY #{order_sql}) AS daily_feed_rank"
      )
      candidate_ids = model
        .from(ranked, :daily_feed_ranked_sources)
        .where("daily_feed_rank <= ?", limit)
        .select("daily_feed_ranked_sources.id")

      model.where(id: candidate_ids)
    end

    def visible_reminder_sql
      <<~SQL.squish
        NOT EXISTS (
          SELECT 1
          FROM feed_item_states
          WHERE feed_item_states.user_id = ?
            AND feed_item_states.item_key = CONCAT('reminder:', reminders.id)
            AND (feed_item_states.dismissed_at IS NOT NULL OR feed_item_states.snoozed_until > ?)
        )
      SQL
    end

    def important_date_section_partition_sql
      today = ApplicationRecord.connection.quote(local_now.to_date)
      <<~SQL.squish
        important_dates.relationship_profile_id,
        CASE WHEN #{important_date_occurrence_sql} = #{today}::date THEN 0 ELSE 1 END
      SQL
    end

    def commitment_section_partition_sql
      today = ApplicationRecord.connection.quote(local_now.to_date)
      <<~SQL.squish
        commitments.relationship_profile_id,
        CASE
          WHEN commitments.due_on < #{today}::date THEN 0
          WHEN commitments.due_on = #{today}::date THEN 1
          ELSE 2
        END
      SQL
    end

    def visible_source_sql(table_name, state_prefix)
      <<~SQL.squish
        NOT EXISTS (
          SELECT 1
          FROM feed_item_states
          WHERE feed_item_states.user_id = ?
            AND feed_item_states.item_key = CONCAT('#{state_prefix}:', #{table_name}.id)
            AND (feed_item_states.dismissed_at IS NOT NULL OR feed_item_states.snoozed_until > ?)
        )
      SQL
    end

    def important_date_occurrence_sql
      @important_date_occurrence_sql ||= begin
        start_date = ApplicationRecord.connection.quote(local_now.to_date)
        end_date = ApplicationRecord.connection.quote(upcoming_end.to_date)
        <<~SQL.squish
          (
            SELECT MIN(candidate.day::date)
            FROM generate_series(#{start_date}::date, #{end_date}::date, interval '1 day') AS candidate(day)
            WHERE important_dates.starts_on <= candidate.day::date
              AND CASE important_dates.recurrence
                WHEN 'none' THEN important_dates.starts_on = candidate.day::date
                WHEN 'weekly' THEN MOD(candidate.day::date - important_dates.starts_on, 7) = 0
                WHEN 'monthly' THEN
                  EXTRACT(DAY FROM candidate.day)::integer = LEAST(
                    EXTRACT(DAY FROM important_dates.starts_on)::integer,
                    EXTRACT(DAY FROM (date_trunc('month', candidate.day) + interval '1 month - 1 day'))::integer
                  )
                WHEN 'yearly' THEN
                  EXTRACT(MONTH FROM candidate.day)::integer = EXTRACT(MONTH FROM important_dates.starts_on)::integer
                  AND EXTRACT(DAY FROM candidate.day)::integer = LEAST(
                    EXTRACT(DAY FROM important_dates.starts_on)::integer,
                    EXTRACT(DAY FROM (date_trunc('month', candidate.day) + interval '1 month - 1 day'))::integer
                  )
                ELSE FALSE
              END
          )
        SQL
      end
    end

    def important_date_candidate_order_sql
      <<~SQL.squish
        #{important_date_occurrence_sql} ASC,
        lower(#{important_date_display_title_sql}) ASC,
        important_dates.id ASC
      SQL
    end

    def important_date_suggestion_candidate_order_sql
      <<~SQL.squish
        #{important_date_occurrence_sql} ASC,
        COALESCE(important_dates.title, '') ASC,
        important_dates.id ASC
      SQL
    end

    def important_date_display_title_sql
      labels = ImportantDate::DATE_TYPES.map do |date_type|
        quoted_type = ApplicationRecord.connection.quote(date_type)
        quoted_label = ApplicationRecord.connection.quote(ImportantDate.date_type_label(date_type))
        "WHEN #{quoted_type} THEN #{quoted_label}"
      end.join(" ")

      <<~SQL.squish
        COALESCE(
          NULLIF(BTRIM(important_dates.title), ''),
          CASE important_dates.date_type #{labels} ELSE important_dates.date_type END
        )
      SQL
    end

    def commitment_candidate_order_sql
      fallback_date = ApplicationRecord.connection.quote(upcoming_end.to_date)
      <<~SQL.squish
        COALESCE(commitments.due_on, #{fallback_date}::date) ASC,
        lower(commitments.title) ASC,
        commitments.id ASC
      SQL
    end

    def suggestions_by_profile
      @suggestions_by_profile ||= begin
        candidates = profiles.to_h do |profile|
          [ profile, suggestions_for_profile(profile) ]
        end
        source_states = suggestion_source_states(candidates.values.flatten)
        candidates.transform_values do |suggestions|
          eligible_source_suggestions(suggestions, source_states:)
        end
      end
    end

    def suggestions_for_profile(profile)
      Suggestions::ForProfile.call(
        relationship_profile: profile,
        as_of:,
        mood_notes: profile.mood_notes,
        important_dates: profile.important_dates,
        interactions: profile.interactions,
        social_context_notes: profile.social_context_notes,
        include_profile_gesture_fallback: false,
        use_preloaded_persona_sources: true
      )
    end

    def suggestion_feedbacks
      @suggestion_feedbacks ||= user.suggestion_feedbacks
        .where(fingerprint: suggestions_by_profile.values.flatten.map(&:fingerprint))
        .index_by(&:fingerprint)
    end

    def suggestion_feed_states
      @suggestion_feed_states ||= user.feed_item_states
        .where(item_key: suggestions_by_profile.flat_map { |profile, suggestions| suggestions.map { |suggestion| suggestion_item_key(profile, suggestion) } })
        .index_by(&:item_key)
    end

    def suggestion_feed_state_hidden?(profile, suggestion)
      return false if include_hidden

      suggestion_feed_states[suggestion_item_key(profile, suggestion)]&.hidden?(at: as_of)
    end

    def eligible_source_suggestions(suggestions, source_states:)
      suggestions.reject { |suggestion| suggestion_source_suppressed?(suggestion, source_states:) }
    end

    def suggestion_source_suppressed?(suggestion, source_states:)
      source = suggestion.reasons.first.source
      return true if source.is_a?(Commitment) && linked_commitment_ids.include?(source.id)
      return true if source.is_a?(ImportantDate) && linked_important_date_ids.include?(source.id)
      return false if include_hidden

      item_key = suggestion_source_item_key(source)
      item_key && source_states[item_key]&.hidden?(at: as_of)
    end

    def suggestion_source_states(suggestions)
      item_keys = suggestions.filter_map { |suggestion| suggestion_source_item_key(suggestion.reasons.first.source) }.uniq
      user.feed_item_states.where(item_key: item_keys).index_by(&:item_key)
    end

    def suggestion_source_item_key(source)
      prefix = FeedItemState::SOURCE_PREFIXES[source.class.base_class.name]
      "#{prefix}:#{source.id}" if prefix
    end

    def suggestion_item_key(profile, suggestion)
      "suggestion:#{profile.id}:#{suggestion.fingerprint}"
    end

    def linked_commitment_ids
      @linked_commitment_ids ||= linked_source_reminders.where.not(commitment_id: nil).distinct.pluck(:commitment_id).to_set
    end

    def linked_important_date_ids
      @linked_important_date_ids ||= linked_source_reminders.where.not(important_date_id: nil).distinct.pluck(:important_date_id).to_set
    end

    def linked_source_reminders
      user.reminders.active.where("#{REMINDER_EFFECTIVE_DELIVERY_SQL} <= ?", upcoming_end)
    end

    def active_profile_ids
      @active_profile_ids || []
    end

    def reject_hidden(items)
      states = user.feed_item_states.where(item_key: items.map(&:key)).index_by(&:item_key)
      items.reject { |item| states[item.key]&.hidden?(at: as_of) }
    end

    def sort(items)
      items.sort_by { |item| [ item.sort_at || upcoming_end, item.title.downcase, item.key ] }
    end

    def upcoming_end
      @upcoming_end ||= local_now.end_of_day + UPCOMING_DAYS.days
    end

    def time_for_date(date)
      zone.local(date.year, date.month, date.day, 9)
    end

    def active_profile(profile)
      profile if profile&.kept? && profile.user_id == user.id
    end

    def relationship_name(profile)
      profile&.display_name.presence || I18n.t("daily_feed.relationship.account")
    end

    def source_label(kind)
      I18n.t("daily_feed.sources.#{kind}")
    end

    def due_context(date)
      date ? I18n.l(date, format: :long) : I18n.t("daily_feed.items.plan_continuation.unscheduled")
    end
  end
end
