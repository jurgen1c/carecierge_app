class RelationshipPersona
  CONFIRMED_MEMORY_SOURCES = %w[user_confirmed user_corrected].freeze
  INCLUDED_MEMORY_STATUSES = %w[active corrected].freeze

  class Trait < Data.define(:statement, :detail, :certainty, :evidence, :source)
    def inferred?
      certainty == "inferred"
    end

    def suggestion_input
      {
        statement:,
        detail:,
        certainty:,
        evidence:,
        source_type: source.class.base_class.name,
        source_id: source.id
      }
    end
  end

  def initialize(relationship_profile:)
    @relationship_profile = relationship_profile
  end

  def traits
    @traits ||= sort_traits(preference_traits + memory_traits)
  end

  def summary
    traits.first(3).map(&:statement).to_sentence
  end

  def suggestion_inputs
    return [] if relationship_profile.archived?

    sort_traits(traits + protected_memory_suggestion_traits).map(&:suggestion_input)
  end

  private

  attr_reader :relationship_profile

  def preference_traits
    relationship_profile.relationship_preferences.order(Arel.sql("lower(key) ASC"), :id).map do |preference|
      build_trait(
        source: preference,
        statement: preference.key,
        detail: preference.value,
        evidence: preference.source_notes.presence || preference.value
      )
    end
  end

  def memory_traits
    relationship_profile.memory_records
      .unprotected
      .where(status: INCLUDED_MEMORY_STATUSES)
      .to_a
      .reject(&:review_required?)
      .map do |memory_record|
        build_trait(
          source: memory_record,
          statement: memory_record.title,
          detail: memory_record.body,
          evidence: memory_record.body
        )
      end
  end

  def protected_memory_suggestion_traits
    relationship_profile.privacy_vault_items
      .suggestion_allowed
      .where(protectable_type: "MemoryRecord")
      .includes(:protectable)
      .filter_map do |item|
        memory_record = item.protectable
        next unless memory_record.status.in?(INCLUDED_MEMORY_STATUSES)
        next if memory_record.review_required?

        build_trait(
          source: memory_record,
          statement: item.payload.fetch("title"),
          detail: item.payload.fetch("body"),
          evidence: item.payload.fetch("body")
        )
      end
  end

  def build_trait(source:, statement:, detail:, evidence:)
    certainty = certainty_for(source)

    Trait.new(
      statement: certainty == "inferred" ? I18n.t("relationship_personas.trait.inferred_statement", trait: statement) : statement,
      detail:,
      certainty:,
      evidence:,
      source:
    )
  end

  def certainty_for(source)
    return "confirmed" if source.is_a?(MemoryRecord) && source.source.in?(CONFIRMED_MEMORY_SOURCES)
    return "inferred" if source.is_a?(MemoryRecord) && source.source == "ai_inferred"
    return "confirmed" if source.confidence == "confirmed"

    "inferred"
  end

  def sort_traits(traits)
    traits.sort_by do |trait|
      [ trait.inferred? ? 1 : 0, trait.statement.downcase, trait.source.id.to_s ]
    end
  end
end
