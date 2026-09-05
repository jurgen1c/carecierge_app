# The owner selects existing work records explicitly; unrelated profile data stays outside this boundary.
class ProfessionalContext
  FIELDS = %w[boundaries organization role goals communication_preferences review_preparation].freeze
  COLLECTIONS = %w[relationship_notes relationship_preferences commitments important_dates gifts].freeze
  Entry = Data.define(:id, :kind, :section, :content, :certainty)

  def initialize(profile, as_of: nil)
    @profile = profile
    @as_of = as_of || OwnerLocalCalendar.date_for(user: profile.user)
  end

  def candidates(collection)
    raise ArgumentError unless COLLECTIONS.include?(collection)

    scope = @profile.public_send(collection)
    return scope.where(private: false).where.missing(:privacy_vault_item).includes(:rich_text_body) if collection == "relationship_notes"

    scope
  end

  def selected(collection)
    candidates(collection).where(id: Array(@profile.professional_context[collection]).compact_blank)
  end

  def entries
    [ entry("professional:mode", "professional", "preferences", "Professional relationship; gifts allowed: #{@profile.professional_gifts_allowed?}") ] +
      details + preference_entries + commitment_entries + date_entries + note_entries + gift_entries
  end

  def label(record)
    case record
    when RelationshipNote then record.body.to_plain_text.squish.truncate(100)
    when RelationshipPreference then "#{record.key}: #{record.value}".truncate(100)
    when ImportantDate then record.display_title
    when Gift then record.name
    else record.title
    end
  end

  private

  def details
    FIELDS.filter_map do |key|
      value = @profile.professional_context[key]
      next if value.blank?
      entry("professional:#{key}", "professional", key == "boundaries" ? "preferences" : "recent_activity", "#{key.humanize}: #{value}")
    end
  end

  def note_entries
    selected("relationship_notes").order(:created_at, :id).map do |note|
      entry("public_note:#{note.id}", "public_note", "recent_activity", note.body.to_plain_text)
    end
  end

  def preference_entries
    selected("relationship_preferences").order(:created_at, :id).map do |preference|
      entry("preference:#{preference.id}", "preference", "preferences", "#{preference.preference_type}: #{preference.key}: #{preference.value}", preference.confirmed? ? "confirmed" : "inferred")
    end
  end

  def commitment_entries
    selected("commitments").where(status: "open").ordered.map do |commitment|
      entry("commitment:#{commitment.id}", "commitment", "commitments", [ commitment.title, commitment.due_on ].compact.join("; "))
    end
  end

  def date_entries
    selected("important_dates").order(:starts_on, :id).filter_map do |date|
      occurrence = date.next_occurrence_on(as_of: @as_of)
      next unless occurrence

      entry("important_date:#{date.id}", "important_date", "important_dates", "#{date.display_title}: #{occurrence}")
    end
  end

  def gift_entries
    return [] unless @profile.professional_gifts_allowed?

    selected("gifts").order(:created_at, :id).map do |gift|
      entry("gift:#{gift.id}", "gift", "recent_activity", "#{gift.name}: #{gift.status}")
    end
  end

  def entry(id, kind, section, content, certainty = "confirmed")
    Entry.new(id:, kind:, section:, content: content.to_s.squish.first(1000), certainty:)
  end
end
