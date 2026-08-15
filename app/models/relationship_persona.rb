class RelationshipPersona
  CONFIRMED_MEMORY_SOURCES = %w[user_confirmed user_corrected].freeze
  INCLUDED_MEMORY_STATUSES = %w[active corrected].freeze
  SUGGESTION_SOURCE_LIMIT = 8

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

  def initialize(relationship_profile:, use_preloaded_associations: false)
    @relationship_profile = relationship_profile
    @use_preloaded_associations = use_preloaded_associations
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

  attr_reader :relationship_profile, :use_preloaded_associations

  def preference_traits
    preference_records.map do |preference|
      build_trait(
        source: preference,
        statement: preference.key,
        detail: preference.value,
        evidence: preference.source_notes.presence || preference.value
      )
    end
  end

  def memory_traits
    unprotected_memory_records
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
    protected_memory_items.filter_map do |item|
        memory_record = protected_memory_record(item)
        next unless memory_record
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

  def preference_records
    association = relationship_profile.association(:relationship_preferences)
    if use_preloaded_associations && association.loaded?
      return association.target.sort_by { |preference| [ preference.key.downcase, preference.id ] }
    end

    relationship_profile.relationship_preferences.order(Arel.sql("lower(key) ASC"), :id).to_a
  end

  def unprotected_memory_records
    memories = relationship_profile.association(:memory_records)
    vault_items = relationship_profile.association(:privacy_vault_items)
    unless use_preloaded_associations && memories.loaded? && vault_items.loaded?
      return relationship_profile.memory_records.unprotected.where(status: INCLUDED_MEMORY_STATUSES).to_a
    end

    protected_ids = vault_items.target.filter_map do |item|
      item.protectable_id if item.protectable_type == "MemoryRecord"
    end.to_set
    memories.target.select { |memory| memory.status.in?(INCLUDED_MEMORY_STATUSES) && !protected_ids.include?(memory.id) }
  end

  def protected_memory_items
    association = relationship_profile.association(:privacy_vault_items)
    if use_preloaded_associations && association.loaded?
      return association.target.select { |item| item.suggestion_allowed? && item.protectable_type == "MemoryRecord" }
    end

    relationship_profile.privacy_vault_items
      .suggestion_allowed
      .where(protectable_type: "MemoryRecord", protectable_id: eligible_protected_memory_ids)
      .order(protected_at: :desc, id: :desc)
      .limit(SUGGESTION_SOURCE_LIMIT)
      .includes(:protectable)
      .to_a
  end

  def eligible_protected_memory_ids
    relationship_profile.memory_records
      .where(status: INCLUDED_MEMORY_STATUSES)
      .where("stale_after IS NULL OR stale_after >= ?", Date.current)
      .select(:id)
  end

  def protected_memory_record(item)
    memories = relationship_profile.association(:memory_records)
    if use_preloaded_associations && memories.loaded?
      return memories.target.find { |memory| memory.id == item.protectable_id }
    end

    item.protectable
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
