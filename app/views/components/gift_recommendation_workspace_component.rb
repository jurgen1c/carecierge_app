class GiftRecommendationWorkspaceComponent < ApplicationViewComponent
  option :relationship_profile
  option :recommendations, default: -> { [] }
  option :permission
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
        inline-flex min-h-11 items-center justify-center rounded-lg border border-private-line bg-canvas px-4 py-2
        text-sm font-semibold text-ink transition hover:bg-stone-100
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :quiet_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg px-4 py-2 text-sm font-semibold text-quiet-note
        transition hover:bg-stone-100 hover:text-ink focus-visible:outline focus-visible:outline-2
        focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  def enabled?
    permission.enabled?
  end

  def field_value(key)
    form_state[key].presence
  end

  def checked?(key)
    ActiveModel::Type::Boolean.new.cast(form_state[key]) || false
  end

  def status_label(recommendation)
    t("gift_recommendations.statuses.#{recommendation.status}")
  end

  def source_certainty_label(source)
    t("gift_recommendations.certainty.#{source.fetch('certainty')}")
  end

  def owner_local_date
    OwnerLocalCalendar.date_for(user: relationship_profile.user)
  end

  def sensitive_source_kind?(recommendation, kind)
    recommendation.source_ids.any? { |source_id| source_id.start_with?("#{kind}:") }
  end
end
