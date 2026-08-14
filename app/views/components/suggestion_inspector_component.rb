class SuggestionInspectorComponent < ApplicationViewComponent
  option :suggestion
  option :relationship_profile
  option :feedback, default: -> { nil }

  style :certainty do
    base { %w[inline-flex rounded-full px-3 py-1 text-xs font-semibold] }
    variants do
      certainty do
        confirmed { %w[bg-emerald-50 text-emerald-900] }
        inferred { %w[bg-amber-50 text-amber-900] }
      end
    end
    defaults { { certainty: :confirmed } }
  end

  def source_label(reason)
    t("suggestions.sources.#{reason.source.class.base_class.model_name.i18n_key}")
  end

  def source_path(reason)
    if reason.source.is_a?(MemoryRecord) && reason.source.vault_protected?
      relationship_profile_privacy_vault_path(relationship_profile)
    else
      relationship_profile_path(
        relationship_profile,
        social_context_page: social_context_page(reason.source),
        anchor: source_anchor(reason.source)
      )
    end
  end

  def source_anchor(source)
    return "contact_rhythm_section" if source.is_a?(ContactCadence)

    dom_id(source, source.is_a?(RelationshipPreference) ? :persona_source : :row)
  end

  def social_context_page(source)
    return unless source.is_a?(SocialContextNote)

    newer_notes = relationship_profile.social_context_notes.where(
      "created_at > :created_at OR (created_at = :created_at AND id > :id)",
      created_at: source.created_at,
      id: source.id
    ).count
    (newer_notes / RelationshipProfileShowWorkspace::SOCIAL_CONTEXT_PAGE_SIZE) + 1
  end
end
