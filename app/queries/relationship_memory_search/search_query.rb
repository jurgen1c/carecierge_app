module RelationshipMemorySearch
  class SearchQuery
    ID_FORMAT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
    SOURCES = %w[profiles notes preferences timeline commitments gifts important_dates].freeze
    STATUSES = %w[active archived all].freeze
    DATE_RANGES = %w[all next_30_days next_month past_year].freeze
    SOURCE_ORDER = SOURCES.index_by(&:itself).freeze
    MAX_QUERY_LENGTH = 200
    MAX_RESULTS_PER_SOURCE = 500
    RICH_TEXT_BODY_SEARCH_EXPRESSION = <<~SQL.squish.freeze
      REPLACE(
        REPLACE(
          REPLACE(
            REPLACE(
              REPLACE(
                REPLACE(
                  REPLACE(
                    REGEXP_REPLACE(
                      REGEXP_REPLACE(COALESCE(action_text_rich_texts.body::text, ''), '<[^>]+>', ' ', 'g'),
                      '\\s+', ' ', 'g'
                    ),
                    '&lt;', '<'
                  ),
                '&gt;', '>'
              ),
              '&quot;', '"'
            ),
            '&#39;', ''''
          ),
          '&apos;', ''''
        ),
        '&nbsp;', ' '
      ),
      '&amp;', '&'
      )
    SQL

    attr_reader :q, :source, :status, :date_range, :relationship_id

    def initialize(relation, params:)
      @relation = relation
      @params = params
      @invalid = false
      @q = scalar_param(:memory_query)&.squish.presence
      @source = catalog_param(:source, [ "all", *SOURCES ], default: "all")
      @status = catalog_param(:status, STATUSES, default: "active")
      @date_range = catalog_param(:date_range, DATE_RANGES, default: "all")
      @relationship_id = relationship_id_param
    end

    def resolve
      return [] if invalid?
      return [] unless searching?

      ActiveSupport::Notifications.instrument(
        "relationship_memory_search.query",
        source:,
        status:,
        date_range:,
        relationship_filter: relationship_id.present?
      ) do |payload|
        results = selected_sources
          .flat_map { |source_type| send("#{source_type}_results") }
          .select { |result| date_matches?(result.occurred_on) }
        results = deduplicated_results(results)
          .sort_by { |result| result_sort_key(result) }
          .first(MAX_RESULTS_PER_SOURCE * selected_sources.size)
        payload[:result_count] = results.size
        results
      end
    end

    def searching?
      invalid? || q.present? || source != "all" || status != "active" || date_range != "all" || relationship_id.present?
    end

    private

    attr_reader :relation, :params

    def selected_sources
      source == "all" ? SOURCES : [ source ]
    end

    def profiles
      @profiles ||= begin
        scoped = case status
        when "archived" then relation.archived
        when "all" then relation
        else relation.active
        end
        scoped = scoped.where(id: relationship_id) if relationship_id.present?
        scoped
      end
    end

    def profile_ids
      profiles.select(:id)
    end

    def profiles_results
      scope = profiles
      if q.present?
        matching_types = RelationshipProfile.type_classes_matching_label(q)
        text_matches = scope.where(
          text_search_condition(
            "first_name",
            "last_name",
            "preferred_name",
            "pronouns",
            "profile_attributes ->> 'custom_type_label'"
          )
        )
        type_matches = scope.where(type: matching_types).where(generic_type_searchable_condition)
        scope = matching_types.empty? ? text_matches : text_matches.or(type_matches)
      end

      bounded(
        scope,
        occurred_on: ->(profile) { next_birthday(profile.birthday) },
        date_filter: annual_date_filter(:birthday),
        order: profile_candidate_order
      ).map do |profile|
        result(
          profile:,
          record: profile,
          source_type: "profiles",
          title: profile.display_name,
          excerpt: profile.relationship_type_label,
          occurred_on: next_birthday(profile.birthday)
        )
      end
    end

    def notes_results
      scope = RelationshipNote
        .where(relationship_profile_id: profile_ids)
        .joins(:rich_text_body)
        .where.missing(:privacy_vault_item)
        .includes(:relationship_profile, :rich_text_body)
      text_matches = text_search(scope, "relationship_notes.category", RICH_TEXT_BODY_SEARCH_EXPRESSION)
      scope = localized_enum_search(
        scope,
        text_matches,
        category: {
          "General" => I18n.t("relationship_searches.note_categories.general"),
          "Private" => I18n.t("relationship_searches.note_categories.private")
        }
      )

      bounded(
        scope,
        occurred_on: ->(note) { note.updated_at },
        date_filter: timestamp_date_filter(:updated_at),
        order: descending_candidate_order(RelationshipNote, :updated_at)
      ).map do |note|
        result(
          profile: note.relationship_profile,
          record: note,
          source_type: "notes",
          title: note_title(note),
          excerpt: note.body.to_plain_text,
          occurred_on: note.updated_at
        )
      end
    end

    def preferences_results
      scope = RelationshipPreference.where(relationship_profile_id: profile_ids).includes(:relationship_profile)
      scope = preferences_search(scope)

      bounded(
        scope,
        occurred_on: ->(preference) { preference.learned_on || preference.updated_at },
        date_filter: date_with_timestamp_fallback_filter(:learned_on, :updated_at),
        order: descending_candidate_order(RelationshipPreference, :learned_on, :updated_at)
      ).map do |preference|
        result(
          profile: preference.relationship_profile,
          record: preference,
          source_type: "preferences",
          title: preference.key,
          excerpt: [ preference.value, preference.source_notes ].compact_blank.join(" — "),
          occurred_on: preference.learned_on || preference.updated_at
        )
      end
    end

    def timeline_results
      entries = TimelineEntry.where(relationship_profile_id: profile_ids).includes(:relationship_profile, :source_record)
      entry_text_matches = text_search(entries, "timeline_entries.title", "timeline_entries.body", "timeline_entries.entry_type")
      entries = localized_enum_search(
        entries,
        entry_text_matches,
        entry_type: TimelineEntry::ENTRY_TYPES.index_with { |value| TimelineEntry.entry_type_label(value) }
      )
      interactions = Interaction.where(relationship_profile_id: profile_ids).includes(:relationship_profile, :source)
      interactions = interactions_search(interactions)

      entry_results = bounded(
        entries,
        occurred_on: ->(entry) { entry.occurred_at },
        date_filter: timestamp_date_filter(:occurred_at),
        order: descending_candidate_order(TimelineEntry, :occurred_at)
      ).map do |entry|
        result(
          profile: entry.relationship_profile,
          record: entry,
          source_type: "timeline",
          title: entry.title,
          excerpt: entry.body.presence || entry.entry_type_label,
          occurred_on: entry.occurred_at
        )
      end
      interaction_results = bounded(
        interactions,
        occurred_on: ->(interaction) { interaction.occurred_at },
        date_filter: timestamp_date_filter(:occurred_at),
        order: descending_candidate_order(Interaction, :occurred_at)
      ).map do |interaction|
        result(
          profile: interaction.relationship_profile,
          record: interaction,
          source_type: "timeline",
          title: I18n.t("relationship_searches.interaction_types.#{interaction.interaction_type}"),
          excerpt: interaction.display_notes.presence || I18n.t("relationship_searches.interaction_types.#{interaction.interaction_type}"),
          occurred_on: interaction.occurred_at
        )
      end

      deduplicated_results(entry_results + interaction_results)
        .sort_by { |result| result_sort_key(result) }
        .first(MAX_RESULTS_PER_SOURCE)
    end

    def commitments_results
      scope = Commitment.where(relationship_profile_id: profile_ids).includes(:relationship_profile)
      text_matches = text_search(scope, "commitments.title", "commitments.notes", "commitments.status")
      scope = localized_enum_search(
        scope,
        text_matches,
        status: Commitment::STATUSES.index_with { |value| Commitment.status_label(value) }
      )

      bounded(
        scope,
        occurred_on: ->(commitment) { commitment.due_on || commitment.updated_at },
        date_filter: date_with_timestamp_fallback_filter(:due_on, :updated_at),
        order: descending_candidate_order(Commitment, :due_on, :updated_at)
      ).map do |commitment|
        result(
          profile: commitment.relationship_profile,
          record: commitment,
          source_type: "commitments",
          title: commitment.title,
          excerpt: commitment.notes.presence || commitment.status_label,
          occurred_on: commitment.due_on || commitment.updated_at
        )
      end
    end

    def gifts_results
      scope = Gift.where(relationship_profile_id: profile_ids).includes(:relationship_profile)
      text_matches = text_search(
        scope,
        "gifts.name",
        "gifts.notes",
        "gifts.occasion",
        "gifts.vendor",
        "gifts.reaction",
        "gifts.status",
        "gifts.outcome"
      )
      scope = localized_enum_search(
        scope,
        text_matches,
        status: Gift::STATUSES.index_with { |value| Gift.status_label(value) },
        outcome: Gift::OUTCOMES.index_with { |value| Gift.outcome_label(value) }
      )

      bounded(
        scope,
        occurred_on: ->(gift) { gift.given_on || gift.updated_at },
        date_filter: date_with_timestamp_fallback_filter(:given_on, :updated_at),
        order: descending_candidate_order(Gift, :given_on, :updated_at)
      ).map do |gift|
        result(
          profile: gift.relationship_profile,
          record: gift,
          source_type: "gifts",
          title: gift.name,
          excerpt: [ gift.occasion, gift.vendor, gift.reaction, gift.notes, gift.status_label ].compact_blank.join(" — "),
          occurred_on: gift.given_on || gift.updated_at
        )
      end
    end

    def important_dates_results
      scope = ImportantDate.where(relationship_profile_id: profile_ids).includes(:relationship_profile)
      text_matches = text_search(
        scope,
        "important_dates.title",
        "important_dates.notes",
        "important_dates.date_type",
        "important_dates.importance_level"
      )
      scope = localized_enum_search(
        scope,
        text_matches,
        date_type: ImportantDate::DATE_TYPES.index_with { |value| ImportantDate.date_type_label(value) },
        importance_level: ImportantDate::IMPORTANCE_LEVELS.index_with { |value| ImportantDate.importance_level_label(value) }
      )

      bounded(
        scope,
        occurred_on: ->(important_date) { important_date_occurrence(important_date) },
        date_filter: important_date_filter,
        order: descending_candidate_order(ImportantDate, :starts_on)
      ).map do |important_date|
        result(
          profile: important_date.relationship_profile,
          record: important_date,
          source_type: "important_dates",
          title: important_date.display_title,
          excerpt: important_date.notes.presence || important_date.date_type_label,
          occurred_on: important_date_occurrence(important_date)
        )
      end
    end

    def important_date_occurrence(important_date)
      as_of = date_range == "all" ? Date.current : selected_date_range.first
      important_date.next_occurrence_on(as_of:) || important_date.starts_on
    end

    def result(profile:, record:, source_type:, title:, excerpt:, occurred_on: nil)
      SearchResult.new(
        relationship_profile: profile,
        source_record: record,
        source_type:,
        title:,
        excerpt:,
        occurred_on:
      )
    end

    def text_search(scope, *columns)
      return scope if q.blank?

      scope.where(text_search_condition(*columns))
    end

    def text_search_condition(*columns)
      condition = columns.map { |column| "LOWER(COALESCE(#{column}, '')) LIKE :term" }.join(" OR ")
      Arel::Nodes::Grouping.new(Arel.sql(condition, term: search_query_attribute))
    end

    def generic_type_searchable_condition
      table = RelationshipProfile.arel_table
      custom_type_label = Arel::Nodes::InfixOperation.new(
        "->>",
        table[:profile_attributes],
        Arel::Nodes.build_quoted("custom_type_label")
      )

      table[:type]
        .not_eq("RelationshipProfiles::Other")
        .or(custom_type_label.eq(nil))
        .or(custom_type_label.eq(""))
    end

    def search_query_attribute
      ActiveRecord::Relation::QueryAttribute.new(
        "memory_query",
        search_term,
        ActiveRecord::Type::String.new
      )
    end

    def interactions_search(scope)
      return scope if q.blank?

      interaction_text_matches = text_search(scope, "interactions.notes", "interactions.interaction_type")
      matching_interactions = localized_enum_search(
        scope,
        interaction_text_matches,
        interaction_type: Interaction::TYPES.index_with do |value|
          I18n.t("relationship_searches.interaction_types.#{value}")
        end
      )
      matching_mood_notes = text_search(
        MoodNote.where(relationship_profile_id: profile_ids),
        "mood_notes.observation",
        "mood_notes.supportive_action",
        "mood_notes.category"
      ).select(:id)
      matching_recaps = text_search(
        ConversationRecap.where(relationship_profile_id: profile_ids),
        "conversation_recaps.title",
        "conversation_recaps.body",
        "conversation_recaps.transcript"
      ).select(:id)

      matching_interactions
        .or(scope.where(source_type: "MoodNote", source_id: matching_mood_notes))
        .or(scope.where(source_type: "ConversationRecap", source_id: matching_recaps))
    end

    def preferences_search(scope)
      return scope if q.blank?

      text_matches = text_search(
        scope,
        "relationship_preferences.key",
        "relationship_preferences.value",
        "relationship_preferences.source_notes",
        "relationship_preferences.preference_type",
        "relationship_preferences.category",
        "relationship_preferences.confidence"
      )
      localized_condition = localized_preference_conditions.reduce(&:or)

      localized_condition ? text_matches.or(scope.where(localized_condition)) : text_matches
    end

    def localized_preference_conditions
      table = RelationshipPreference.arel_table
      {
        preference_type: RelationshipPreference.preference_types,
        category: RelationshipPreference.categories,
        confidence: RelationshipPreference.confidences
      }.filter_map do |attribute, values|
        matching_values = values.keys.select do |value|
          I18n.t("relationship_preferences.#{attribute.to_s.pluralize}.#{value}").downcase.include?(q.downcase)
        end
        table[attribute].in(matching_values) if matching_values.any?
      end
    end

    def localized_enum_search(scope, text_matches, **labels_by_attribute)
      return text_matches if q.blank?

      table = scope.klass.arel_table
      localized_condition = labels_by_attribute.filter_map do |attribute, labels|
        matching_values = labels.filter_map do |value, label|
          value if label.to_s.downcase.include?(q.downcase)
        end
        table[attribute].in(matching_values) if matching_values.any?
      end.reduce(&:or)

      localized_condition ? text_matches.or(scope.where(localized_condition)) : text_matches
    end

    def note_title(note)
      translation_key = { "General" => "general", "Private" => "private" }[note.category]
      return I18n.t("relationship_searches.note_categories.#{translation_key}") if translation_key

      note.category.presence || note.model_name.human
    end

    def bounded(scope, occurred_on:, date_filter:, order:)
      scope = date_filter.call(scope, selected_date_range) if date_range != "all" && date_filter
      candidates = scope.reorder(*order).limit(MAX_RESULTS_PER_SOURCE).to_a
      return candidates if date_range == "all" || occurred_on.nil?

      candidates.select { |record| date_matches?(occurred_on.call(record)&.to_date) }
    end

    def descending_candidate_order(model, *attributes)
      table = model.arel_table
      [ *attributes.map { |attribute| table[attribute].desc.nulls_last }, table[:id].asc ]
    end

    def profile_candidate_order
      table = RelationshipProfile.arel_table
      display_name = Arel::Nodes::NamedFunction.new(
        "COALESCE",
        [ Arel::Nodes::NamedFunction.new("NULLIF", [ table[:preferred_name], Arel::Nodes.build_quoted("") ]), table[:first_name] ]
      )

      [ Arel::Nodes::NamedFunction.new("LOWER", [ display_name ]).asc, table[:id].asc ]
    end

    def timestamp_date_filter(attribute)
      lambda do |scope, range|
        table = scope.klass.arel_table
        scope.where(table[attribute].between(timestamp_range(range)))
      end
    end

    def date_with_timestamp_fallback_filter(date_attribute, timestamp_attribute)
      lambda do |scope, range|
        table = scope.klass.arel_table
        date_match = table[date_attribute].between(range)
        timestamp_match = table[date_attribute].eq(nil)
          .and(table[timestamp_attribute].between(timestamp_range(range)))
        scope.where(date_match.or(timestamp_match))
      end
    end

    def annual_date_filter(attribute)
      lambda do |scope, range|
        return scope.where.not(attribute => nil) if date_range == "past_year"

        table = scope.klass.arel_table
        scope.where(annual_month_day_condition(table, attribute, range))
      end
    end

    def important_date_filter
      lambda do |scope, range|
        table = scope.klass.arel_table
        starts_on = table[:starts_on]
        recurrence = table[:recurrence]
        nonrecurring = recurrence.eq("none").and(starts_on.between(range))
        recurring = if date_range == "past_year"
          recurrence.in(%w[yearly monthly weekly]).and(starts_on.lteq(range.last))
        else
          yearly = recurrence.eq("yearly")
            .and(starts_on.lteq(range.last))
            .and(annual_month_day_condition(table, :starts_on, range))
          monthly_or_weekly = recurrence.in(%w[monthly weekly]).and(starts_on.lteq(range.last))
          yearly.or(monthly_or_weekly)
        end

        scope.where(nonrecurring.or(recurring))
      end
    end

    def annual_month_day_condition(table, attribute, range)
      formatted_date = Arel::Nodes::NamedFunction.new(
        "TO_CHAR",
        [ table[attribute], Arel::Nodes.build_quoted("MM-DD") ]
      )
      formatted_date.in(annual_month_days(range))
    end

    def annual_month_days(range)
      range.flat_map do |date|
        values = [ date.strftime("%m-%d") ]
        values << "02-29" if date.month == 2 && date.day == 28 && !Date.gregorian_leap?(date.year)
        values
      end.uniq
    end

    def timestamp_range(range)
      range.first.beginning_of_day..range.last.end_of_day
    end

    def deduplicated_results(results)
      results
        .group_by { |result| canonical_source_key(result.source_record) }
        .values
        .map { |matches| matches.min_by { |result| derivative_result?(result.source_record) ? 1 : 0 } }
    end

    def canonical_source_key(record)
      source = case record
      when TimelineEntry then record.source_record || record
      when Interaction then record.source || record
      else record
      end

      [ source.class.base_class.name, source.id ]
    end

    def derivative_result?(record)
      (record.is_a?(TimelineEntry) && record.source_record.present?) ||
        (record.is_a?(Interaction) && record.source.present?)
    end

    def search_term
      "%#{ActiveRecord::Base.sanitize_sql_like(q.downcase)}%"
    end

    def date_matches?(date)
      return true if date_range == "all"
      return false if date.blank?

      date.in?(selected_date_range)
    end

    def selected_date_range
      case date_range
      when "next_30_days" then Date.current..(Date.current + 30.days)
      when "next_month" then Date.current.next_month.all_month
      when "past_year" then 1.year.ago.to_date..Date.current
      end
    end

    def next_birthday(birthday)
      return if birthday.blank?

      reference_date = date_range == "all" ? Date.current : selected_date_range.first
      occurrence = safe_date(reference_date.year, birthday.month, birthday.day)
      occurrence < reference_date ? safe_date(reference_date.year + 1, birthday.month, birthday.day) : occurrence
    end

    def safe_date(year, month, day)
      Date.new(year, month, [ day, Time.days_in_month(month, year) ].min)
    end

    def result_sort_key(result)
      [
        result.relationship_profile.display_name.downcase,
        SOURCE_ORDER.fetch(result.source_type),
        -(result.occurred_on&.jd || 0),
        result.title.downcase,
        result.source_record.id
      ]
    end

    def catalog_param(key, catalog, default:)
      value = scalar_param(key)
      return default if value.blank?
      return value if value.in?(catalog)

      invalidate
      default
    end

    def relationship_id_param
      value = scalar_param(:relationship_id)
      return if value.blank?
      return value.downcase if value.match?(ID_FORMAT)

      invalidate
    end

    def scalar_param(key)
      value = params[key]
      return if value.nil? || value == ""
      if value.is_a?(String) || value.is_a?(Symbol)
        normalized = value.to_s.first(MAX_QUERY_LENGTH)
        return normalized if normalized.valid_encoding? && !normalized.include?("\0")
      end

      invalidate
    end

    def invalidate
      @invalid = true
      nil
    end

    def invalid?
      @invalid
    end
  end
end
