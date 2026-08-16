require "digest"
require "json"

module RelationshipBriefings
  class ContextBuilder
    MAX_SOURCES = 40
    MAX_PER_KIND = 8
    MAX_SOURCE_CHARACTERS = 700
    MAX_TOTAL_CHARACTERS = 12_000

    Source = Data.define(:id, :kind, :section, :content, :certainty, :label, :sensitive)
    Result = Data.define(:sources, :categories, :fingerprint)

    def initialize(
      relationship_profile:,
      include_private_notes: false,
      include_vault_context: false,
      locale: I18n.locale,
      as_of: nil
    )
      @relationship_profile = relationship_profile
      @include_private_notes = include_private_notes
      @include_vault_context = include_vault_context
      @locale = locale.to_sym
      @time_zone = owner_time_zone
      @as_of = local_date(as_of || Time.current)
    end

    def call
      bounded_sources = bound_sources(sources)
      Result.new(
        sources: bounded_sources,
        categories: bounded_sources.map { |source| category_for(source.kind) }.uniq,
        fingerprint: Digest::SHA256.hexdigest(JSON.generate(bounded_sources.map(&:to_h)))
      )
    end

    private

    attr_reader :relationship_profile, :include_private_notes, :include_vault_context, :locale, :as_of, :time_zone

    def sources
      private_sources = note_sources(private: true)
      selected_vault_sources = vault_sources
      reserved_sensitive_sources = [ private_sources.first, selected_vault_sources.first ].compact

      reserved_sensitive_sources +
        timeline_sources +
        commitment_sources +
        important_date_sources +
        preference_sources +
        note_sources(private: false) +
        private_sources.drop(1) +
        selected_vault_sources.drop(1)
    end

    def timeline_sources
      relationship_profile.timeline_entries.ordered.limit(MAX_PER_KIND).map do |entry|
        source(
          id: "timeline:#{entry.id}",
          kind: "timeline",
          section: "recent_activity",
          content: [ entry.title, entry.body ].compact_blank.join(": "),
          certainty: entry.entry_type == "ai_extraction" ? "inferred" : "confirmed",
          label: label("timeline", date: local_date(entry.occurred_at))
        )
      end
    end

    def commitment_sources
      relationship_profile.commitments.where(status: "open").ordered.limit(MAX_PER_KIND).map do |commitment|
        details = [ commitment.title ]
        details << "due #{commitment.due_on.iso8601}" if commitment.due_on
        source(
          id: "commitment:#{commitment.id}",
          kind: "commitment",
          section: "commitments",
          content: details.join("; "),
          certainty: "confirmed",
          label: label("commitment")
        )
      end
    end

    def important_date_sources
      relationship_profile.association(:important_dates).reset
      important_dates = relationship_profile.upcoming_important_dates(as_of:).sort_by do |important_date|
        [ important_date.next_occurrence_on(as_of:), important_date.display_title.downcase, important_date.id ]
      end.first(MAX_PER_KIND)

      important_dates.map do |important_date|
        occurrence = important_date.next_occurrence_on(as_of:)
        source(
          id: "important_date:#{important_date.id}",
          kind: "important_date",
          section: "important_dates",
          content: "#{important_date.display_title}: #{occurrence.iso8601}",
          certainty: "confirmed",
          label: label("important_date", date: occurrence)
        )
      end
    end

    def preference_sources
      relationship_profile.relationship_preferences.order(:created_at, :id).limit(MAX_PER_KIND).map do |preference|
        source(
          id: "preference:#{preference.id}",
          kind: "preference",
          section: "preferences",
          content: "#{preference.key}: #{preference.value}",
          certainty: preference.confidence == "confirmed" ? "confirmed" : "inferred",
          label: label("preference")
        )
      end
    end

    def note_sources(private:)
      return [] if private && !include_private_notes

      relationship_profile.relationship_notes
        .where(private:)
        .where.missing(:privacy_vault_item)
        .includes(:rich_text_body)
        .order(created_at: :desc, id: :desc)
        .limit(MAX_PER_KIND)
        .filter_map do |note|
          content = note.body.to_plain_text.squish
          next if content.blank?

          source(
            id: "#{private ? 'private_note' : 'public_note'}:#{note.id}",
            kind: private ? "private_note" : "public_note",
            section: private ? "sensitive_context" : "recent_activity",
            content:,
            certainty: "confirmed",
            label: label(private ? "private_note" : "public_note", date: local_date(note.created_at)),
            sensitive: private
          )
        end
    end

    def vault_sources
      return [] unless include_vault_context

      relationship_profile.privacy_vault_items.ordered.limit(MAX_PER_KIND).map do |item|
        source(
          id: "vault:#{item.id}",
          kind: "vault",
          section: "sensitive_context",
          content: "#{item.display_title}: #{plain_text(item.display_body)}",
          certainty: vault_certainty(item),
          label: label("vault", date: local_date(item.protected_at)),
          sensitive: true
        )
      end
    end

    def source(id:, kind:, section:, content:, certainty:, label:, sensitive: false)
      Source.new(
        id:,
        kind:,
        section:,
        content: content.to_s.squish.first(MAX_SOURCE_CHARACTERS),
        certainty:,
        label: label.to_s.first(RelationshipBriefing::MAX_SOURCE_LABEL_LENGTH),
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

    def label(kind, date: nil)
      I18n.with_locale(locale) do
        I18n.t(
          "relationship_briefings.sources.#{kind}",
          date: date && I18n.l(date, format: :long),
          default: kind.humanize
        )
      end
    end

    def category_for(kind)
      {
        "commitment" => "commitments",
        "important_date" => "important_dates",
        "preference" => "preferences",
        "public_note" => "public_notes",
        "private_note" => "private_notes"
      }.fetch(kind, kind)
    end

    def vault_certainty(item)
      item.protectable.is_a?(MemoryRecord) && item.protectable.source == "ai_inferred" ? "inferred" : "confirmed"
    end

    def plain_text(value)
      ActionText::Content.new(value.to_s).to_plain_text.squish
    end

    def owner_time_zone
      time_zone_name = relationship_profile.user.notification_preference&.time_zone.presence
      (ActiveSupport::TimeZone[time_zone_name] if time_zone_name) || Time.zone
    end

    def local_date(value)
      return value if value.is_a?(Date) && !value.is_a?(DateTime)

      value.in_time_zone(time_zone).to_date
    end
  end
end
