class PersonaTraitComponent < ApplicationViewComponent
  option :trait
  option :relationship_profile

  style :badge do
    base { %w[inline-flex w-fit items-center rounded-full px-3 py-1 text-xs font-semibold] }
    variants do
      tone do
        confirmed { %w[bg-emerald-50 text-emerald-900] }
        inferred { %w[bg-amber-50 text-amber-900] }
      end
    end
  end

  def badge_tone
    trait.certainty.to_sym
  end

  def correction_path
    case trait.source
    when MemoryRecord
      edit_relationship_profile_memory_record_path(relationship_profile, trait.source)
    when RelationshipPreference
      edit_relationship_profile_path(relationship_profile, anchor: helpers.dom_id(trait.source, :fields))
    end
  end

  def correction_turbo_frame
    return helpers.dom_id(trait.source) if trait.source.is_a?(MemoryRecord)

    "_top"
  end

  def evidence_path
    anchor = case trait.source
    when MemoryRecord
      helpers.dom_id(trait.source, :row)
    when RelationshipPreference
      helpers.dom_id(trait.source, :persona_source)
    end

    relationship_profile_path(relationship_profile, anchor:)
  end
end
