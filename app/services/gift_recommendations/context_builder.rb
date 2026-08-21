require "digest"
require "json"

module GiftRecommendations
  class ContextBuilder
    MAX_SOURCES = 40
    MAX_PER_KIND = 8
    MAX_SOURCE_CHARACTERS = 700
    MAX_SELECTED_SENSITIVE_SOURCE_CHARACTERS = 400
    MAX_TOTAL_CHARACTERS = 12_000

    Source = Data.define(:id, :kind, :content, :certainty, :label, :sensitive)
    Result = Data.define(:sources, :categories, :fingerprint)

    def initialize(relationship_profile:, private_note_ids: [], vault_item_ids: [], locale: I18n.locale, as_of: nil)
      @relationship_profile = relationship_profile
      @private_note_ids = Array(private_note_ids).compact_blank.map(&:to_s).uniq
      @vault_item_ids = Array(vault_item_ids).compact_blank.map(&:to_s).uniq
      @locale = locale.to_sym
      @as_of = OwnerLocalCalendar.date_for(user: relationship_profile.user, at: as_of || Time.current)
    end

    def call
      selected_sources = bound_sources(sources)
      Result.new(
        sources: selected_sources,
        categories: selected_sources.map { |source| category_for(source.kind) }.uniq,
        fingerprint: Digest::SHA256.hexdigest(JSON.generate(selected_sources.map(&:to_h)))
      )
    end

    private

    attr_reader :relationship_profile, :private_note_ids, :vault_item_ids, :locale, :as_of

    def sources
      private_sources = selected_private_note_sources
      protected_sources = selected_vault_sources
      preferences = preference_sources
      constraint_sources, ordinary_preference_sources = preferences.partition { |candidate| candidate.kind == "constraint" }

      constraint_sources +
        private_sources +
        protected_sources +
        profile_sources +
        ordinary_preference_sources +
        desire_sources +
        gift_sources +
        important_date_sources +
        public_note_sources
    end

    def profile_sources
      [ source(
        id: "profile:#{relationship_profile.id}",
        kind: "relationship",
        content: relationship_profile.relationship_type_label,
        certainty: "confirmed",
        label: label("relationship")
      ) ]
    end

    def preference_sources
      relationship_profile.relationship_preferences
        .order(Arel.sql(<<~SQL.squish), :created_at, :id)
          CASE
            WHEN preference_type IN ('constraint', 'negative')
              OR category IN ('boundaries', 'allergies', 'cultural_constraints')
            THEN 0
            ELSE 1
          END
        SQL
        .limit(MAX_PER_KIND)
        .map do |preference|
        kind = hard_constraint_preference?(preference) ? "constraint" : "preference"
        source(
          id: "preference:#{preference.id}",
          kind:,
          content: "#{preference.preference_type}: #{preference.key}: #{preference.value}",
          certainty: preference.confidence == "confirmed" ? "confirmed" : "inferred",
          label: label(kind)
        )
      end
    end

    def hard_constraint_preference?(preference)
      preference.preference_type.in?(%w[constraint negative]) ||
        preference.category.in?(%w[boundaries allergies cultural_constraints])
    end

    def desire_sources
      relationship_profile.desires.where(status: Desire::EDITABLE_STATUSES).ordered.order(:id).limit(MAX_PER_KIND).map do |desire|
        source(
          id: "desire:#{desire.id}",
          kind: "desire",
          content: [ desire.title, desire.notes ].compact_blank.join(": "),
          certainty: desire.source == "manual" ? "confirmed" : "inferred",
          label: label("desire")
        )
      end
    end

    def gift_sources
      relationship_profile.gifts.ordered.order(:id).limit(MAX_PER_KIND).map do |gift|
        details = [ gift.name, gift.status, gift.occasion, gift.reaction, gift.outcome ].compact_blank
        source(
          id: "gift:#{gift.id}",
          kind: "gift",
          content: details.join("; "),
          certainty: "confirmed",
          label: label("gift")
        )
      end
    end

    def important_date_sources
      relationship_profile.association(:important_dates).reset
      relationship_profile.upcoming_important_dates(as_of:).sort_by do |important_date|
        [ important_date.next_occurrence_on(as_of:), important_date.display_title.downcase, important_date.id ]
      end.first(MAX_PER_KIND).map do |important_date|
        occurrence = important_date.next_occurrence_on(as_of:)
        source(
          id: "important_date:#{important_date.id}",
          kind: "important_date",
          content: "#{important_date.display_title}: #{occurrence.iso8601}",
          certainty: "confirmed",
          label: label("important_date", date: occurrence)
        )
      end
    end

    def public_note_sources
      note_sources(
        relationship_profile.relationship_notes.where(private: false).where.missing(:privacy_vault_item),
        kind: "public_note",
        sensitive: false
      )
    end

    def selected_private_note_sources
      return [] if private_note_ids.empty?

      note_sources(
        relationship_profile.relationship_notes.where(private: true, id: private_note_ids).where.missing(:privacy_vault_item),
        kind: "private_note",
        sensitive: true
      )
    end

    def note_sources(scope, kind:, sensitive:)
      scope.includes(:rich_text_body).order(:created_at, :id).limit(MAX_PER_KIND).filter_map do |note|
        content = note.body.to_plain_text.squish
        next if content.blank?

        source(
          id: "#{kind}:#{note.id}",
          kind:,
          content:,
          certainty: "confirmed",
          label: label(kind),
          sensitive:,
          max_characters: sensitive ? MAX_SELECTED_SENSITIVE_SOURCE_CHARACTERS : MAX_SOURCE_CHARACTERS
        )
      end
    end

    def selected_vault_sources
      return [] if vault_item_ids.empty?

      relationship_profile.privacy_vault_items.suggestion_allowed.where(id: vault_item_ids).ordered.limit(MAX_PER_KIND).map do |item|
        source(
          id: "vault:#{item.id}",
          kind: "vault",
          content: "#{item.display_title}: #{plain_text(item.display_body)}",
          certainty: vault_certainty(item),
          label: label("vault"),
          sensitive: true,
          max_characters: MAX_SELECTED_SENSITIVE_SOURCE_CHARACTERS
        )
      end
    end

    def source(id:, kind:, content:, certainty:, label:, sensitive: false, max_characters: MAX_SOURCE_CHARACTERS)
      Source.new(
        id:,
        kind:,
        content: content.to_s.squish.first(max_characters),
        certainty:,
        label: label.to_s.first(GiftRecommendation::MAX_SOURCE_LABEL_LENGTH),
        sensitive:
      )
    end

    def bound_sources(candidates)
      remaining = MAX_TOTAL_CHARACTERS
      candidates.first(MAX_SOURCES).filter_map do |candidate|
        next if remaining <= 0 || candidate.content.blank?

        content = candidate.content.first(remaining)
        remaining -= content.length
        candidate.with(content:)
      end
    end

    def category_for(kind)
      {
        "preference" => "preferences",
        "constraint" => "constraints",
        "desire" => "desires",
        "gift" => "gift_history",
        "important_date" => "important_dates",
        "public_note" => "public_notes",
        "private_note" => "private_notes"
      }.fetch(kind, kind)
    end

    def label(kind, date: nil)
      I18n.with_locale(locale) do
        I18n.t("gift_recommendations.sources.#{kind}", date:, default: kind.humanize)
      end
    end

    def vault_certainty(item)
      item.protectable.is_a?(MemoryRecord) && item.protectable.source == "ai_inferred" ? "inferred" : "confirmed"
    end

    def plain_text(value)
      ActionText::Content.new(value.to_s).to_plain_text.squish
    end
  end
end
