module MessageDrafts
  class ContextBuilder
    MAX_CHARACTERS = 6_000
    MAX_ENTRY_CHARACTERS = 1_000
    MAX_LABEL_CHARACTERS = 200
    MAX_PER_CATEGORY = 10
    Result = Data.define(:text, :categories)

    def initialize(relationship_profile:, include_private_notes: false, include_vault_context: false, social_context_notes: nil)
      @relationship_profile = relationship_profile
      @include_private_notes = include_private_notes
      @include_vault_context = include_vault_context
      @social_context_notes = social_context_notes
    end

    def call
      selected_lines = []
      selected_categories = []
      remaining = MAX_CHARACTERS

      entries.each do |category, label, value|
        entry = bounded_entry(label, value)
        next if entry.blank? || remaining <= 0

        selected_line = "#{entry}\n".first(remaining)
        selected_lines << selected_line
        selected_categories << category
        remaining -= selected_line.length
      end

      Result.new(text: selected_lines.join.strip, categories: selected_categories.uniq)
    end

    private

    attr_reader :relationship_profile, :include_private_notes, :include_vault_context, :social_context_notes

    def bounded_entry(label, value)
      bounded_label = label.to_s.squish.first(MAX_LABEL_CHARACTERS)
      value_limit = MAX_ENTRY_CHARACTERS - bounded_label.length - 2

      "#{bounded_label}: #{value.to_s.squish.first(value_limit)}"
    end

    def entries
      private_entries = private_note_entries
      protected_entries = vault_entries

      private_entries.first(1) +
        protected_entries.first(1) +
        profile_entries +
        important_date_entries +
        preference_entries +
        note_entries(notes(private: false), "public_notes", "Public note") +
        social_context_entries +
        memory_entries +
        private_entries.drop(1) +
        protected_entries.drop(1)
    end

    def profile_entries
      [
        [ "profile", "Preferred name", relationship_profile.display_name ],
        [ "profile", "Full name", relationship_profile.full_name ],
        [ "profile", "Relationship", relationship_profile.relationship_type_label ],
        [ "profile", "Pronouns", relationship_profile.pronouns ],
        [ "profile", "Birthday", relationship_profile.birthday ]
      ].select { |entry| entry.last.present? } + relationship_detail_entries
    end

    def relationship_detail_entries
      relationship_profile.visible_relationship_field_values.first(MAX_PER_CATEGORY).map do |field_value|
        [ "profile", field_value.display_label, field_value.value ]
      end
    end

    def important_date_entries
      relationship_profile.important_dates.order(:starts_on).limit(MAX_PER_CATEGORY).map do |important_date|
        [ "important_dates", important_date.display_title, important_date.starts_on ]
      end
    end

    def preference_entries
      relationship_profile.relationship_preferences.order(:created_at).limit(MAX_PER_CATEGORY).map do |preference|
        metadata = [ "confidence: #{preference.confidence}" ]
        metadata << "source: #{preference.source_notes.to_s.squish.first(200)}" if preference.source_notes.present?

        [ "preferences", preference.key, "[#{metadata.join('; ')}] #{preference.value}" ]
      end
    end

    def note_entries(notes, category, label)
      notes.first(MAX_PER_CATEGORY).filter_map do |note|
        body = note.body.to_plain_text.squish
        [ category, label, body ] if body.present?
      end
    end

    def memory_entries
      relationship_profile.memory_records
        .unprotected
        .where(status: %w[active corrected])
        .where("stale_after IS NULL OR stale_after >= ?", Date.current)
        .order(:created_at)
        .limit(MAX_PER_CATEGORY)
        .map do |memory|
          metadata = "source: #{memory.source}; confidence: #{memory.confidence}"
          [ "memories", memory.title, "[#{metadata}] #{memory.body}" ]
        end
    end

    def social_context_entries
      social_context_sources.flat_map do |note|
        entries = [
          [ "social_context", "User-provided social context", "[source: user_provided] #{note.body.to_plain_text.squish}" ]
        ]
        if note.approved_suggested_uses.include?("message") && note.interpretation.present?
          entries << [
            "social_context",
            "Approved social context interpretation",
            "[source: ai_inferred; review_status: approved] #{note.interpretation.to_s.squish}"
          ]
        end
        entries
      end
    end

    def social_context_sources
      sources = social_context_notes ||
        relationship_profile.social_context_notes
          .downstream_sources
          .to_a

      SocialContextNote.select_downstream_sources(sources)
    end

    def private_note_entries
      return [] unless include_private_notes

      note_entries(notes(private: true), "private_notes", "Private note")
    end

    def vault_entries
      return [] unless include_vault_context

      relationship_profile.privacy_vault_items.ordered.limit(MAX_PER_CATEGORY).map do |item|
        [ "vault", item.display_title, plain_text(item.display_body) ]
      end
    end

    def notes(private:)
      relationship_profile.relationship_notes
        .where(private:)
        .where.missing(:privacy_vault_item)
        .includes(:rich_text_body)
        .order(:created_at)
        .limit(MAX_PER_CATEGORY)
    end

    def plain_text(value)
      ActionText::Content.new(value.to_s).to_plain_text.squish
    end
  end
end
