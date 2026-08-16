module RelationshipBriefings
  class Generate
    def self.call(
      actor:,
      relationship_profile:,
      interaction_context:,
      include_private_notes: false,
      include_vault_context: false,
      vault_lease: nil,
      locale: I18n.locale,
      generator: OpenAiGenerator.new
    )
      new(
        actor:,
        relationship_profile:,
        interaction_context:,
        include_private_notes:,
        include_vault_context:,
        vault_lease:,
        locale:,
        generator:
      ).call
    end

    def initialize(
      actor:,
      relationship_profile:,
      interaction_context:,
      include_private_notes:,
      include_vault_context:,
      vault_lease:,
      locale:,
      generator:
    )
      @actor = actor
      @relationship_profile = relationship_profile
      @interaction_context = interaction_context.to_s.squish
      @include_private_notes = include_private_notes
      @include_vault_context = include_vault_context
      @vault_lease = vault_lease
      @locale = locale.to_sym
      @generator = generator
    end

    def call
      generation_version, initial_context = prepare_generation!
      raw_sections = generator.generate(
        interaction_context:,
        sources: initial_context.sources,
        locale:
      )

      actor.with_lock do
        relationship_profile.with_lock do
          validate_profile!
          validate_vault_access!
          current_context = build_context
          reject_stale_generation!(generation_version:, initial_context:, current_context:)
          sections = enrich_sections(raw_sections, sources: current_context.sources)

          dismiss_generated_briefings!
          briefing = relationship_profile.relationship_briefings.create!(
            user: actor,
            interaction_context:,
            sections:,
            context_categories: current_context.categories,
            status: "generated",
            locale: locale.to_s,
            include_private_notes:,
            include_vault_context:,
            generated_at: Time.current
          )
          AuditEvent.record!(
            user: actor,
            actor:,
            action: "relationship_briefing.generated",
            target: relationship_profile,
            metadata: { result: "generated" }
          )
          briefing
        end
      end
    end

    private

    attr_reader :actor,
      :relationship_profile,
      :interaction_context,
      :include_private_notes,
      :include_vault_context,
      :vault_lease,
      :locale,
      :generator

    def prepare_generation!
      actor.with_lock do
        relationship_profile.with_lock do
          validate_profile!
          validate_settings!
          validate_vault_access!
          context = build_context
          record_sensitive_access(context.categories)
          relationship_profile.increment!(:briefing_generation_version)
          [ relationship_profile.briefing_generation_version, context ]
        end
      end
    end

    def validate_profile!
      raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
    end

    def validate_settings!
      candidate = RelationshipBriefing.new(
        user: actor,
        relationship_profile:,
        interaction_context:,
        sections: [],
        status: "generated",
        locale: locale.to_s,
        generated_at: Time.current
      )
      raise ActiveRecord::RecordInvalid, candidate unless candidate.valid?
    end

    def validate_vault_access!
      return unless include_vault_context
      return if vault_lease&.active_for?(actor)

      raise VaultAccessError, "Privacy vault access is required"
    end

    def build_context
      ContextBuilder.new(
        relationship_profile:,
        include_private_notes:,
        include_vault_context:,
        locale:
      ).call
    end

    def reject_stale_generation!(generation_version:, initial_context:, current_context:)
      return if relationship_profile.briefing_generation_version == generation_version &&
        initial_context.fingerprint == current_context.fingerprint

      raise GenerationSupersededError, "A newer request or source change superseded this briefing"
    end

    def enrich_sections(raw_sections, sources:)
      raise GenerationError, "Relationship briefing response was invalid" unless raw_sections.is_a?(Array)

      source_by_id = sources.index_by(&:id)
      raw_sections.map do |raw_section|
        section = raw_section.to_h.deep_stringify_keys
        {
          "key" => section.fetch("key"),
          "items" => Array(section.fetch("items")).map do |raw_item|
            enrich_item(raw_item.to_h.deep_stringify_keys, source_by_id:)
          end
        }
      end
    rescue KeyError, NoMethodError, TypeError
      raise GenerationError, "Relationship briefing response was invalid"
    end

    def enrich_item(item, source_by_id:)
      source_ids = item.fetch("source_ids")
      raise GenerationError, "Relationship briefing response was invalid" unless source_ids.is_a?(Array) && source_ids.present?

      cited_sources = source_ids.uniq.map do |source_id|
        source_by_id[source_id] || raise(GenerationError, "Relationship briefing cited an unknown source")
      end
      requested_certainty = item.fetch("certainty")
      certainty = if requested_certainty == "confirmed" && cited_sources.all? { |source| source.certainty == "confirmed" }
        "confirmed"
      else
        "inferred"
      end

      {
        "body" => item.fetch("body").to_s.squish,
        "certainty" => certainty,
        "sources" => cited_sources.map do |source|
          { "id" => source.id, "label" => source.label, "sensitive" => source.sensitive }
        end
      }
    end

    def dismiss_generated_briefings!
      relationship_profile.relationship_briefings.where(status: "generated").update_all(
        status: "dismissed",
        dismissed_at: Time.current,
        updated_at: Time.current
      )
    end

    def record_sensitive_access(categories)
      return if (categories & %w[private_notes vault]).empty?

      AuditEvent.record!(
        user: actor,
        actor:,
        action: "sensitive_record.accessed",
        target: relationship_profile,
        metadata: { result: "relationship_briefing" }
      )
      return unless categories.include?("vault")

      VaultAccessEvent.record_safely(
        event_type: "viewed",
        user: actor,
        relationship_profile:
      )
    end
  end
end
