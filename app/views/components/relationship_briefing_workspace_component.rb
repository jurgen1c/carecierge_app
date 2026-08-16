class RelationshipBriefingWorkspaceComponent < ApplicationViewComponent
  option :relationship_profile
  option :briefing, default: -> { nil }
  option :form_state, default: -> { {} }
  option :private_notes_available, default: -> { false }
  option :vault_items_available, default: -> { false }
  option :vault_unlocked, default: -> { false }

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-5 py-3
        text-sm font-semibold text-canvas transition hover:bg-primary-hover
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :secondary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-stone-300 bg-canvas px-4 py-2
        text-sm font-semibold text-ink transition hover:bg-stone-100
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :certainty_badge do
    base { %w[inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold] }
    variants do
      certainty do
        confirmed { %w[border-primary/30 bg-surface text-primary] }
        inferred { %w[border-stone-300 bg-stone-100 text-quiet-note] }
      end
    end
    defaults { { certainty: :inferred } }
  end

  def interaction_context
    form_state.fetch(:interaction_context, briefing&.interaction_context).to_s
  end

  def include_private_notes?
    selected?(form_state[:include_private_notes])
  end

  def include_vault_context?
    selected?(form_state[:include_vault_context])
  end

  def section_title(key)
    t("relationship_briefings.sections.#{key}")
  end

  def certainty_label(value)
    t("relationship_briefings.certainty.#{value}")
  end

  private

  def selected?(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end
end
