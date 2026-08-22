class PersonalTouchChecklistComponent < ApplicationViewComponent
  option :relationship_profile
  option :moment
  option :checklist, default: -> { nil }
  option :compact, default: -> { false }

  style :container do
    base { %w[border border-private-line bg-canvas] }
    variants do
      compact do
        yes { %w[mt-4 rounded-xl p-4] }
        no { %w[rounded-2xl p-5 sm:p-6] }
      end
    end
    defaults { { compact: false } }
  end

  style :category_badge do
    base { %w[inline-flex rounded-full border border-private-line bg-surface px-2.5 py-1 text-xs font-semibold text-quiet-note] }
  end

  style :quiet_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-private-line bg-canvas px-3 py-2
        text-sm font-semibold text-ink transition hover:bg-surface disabled:cursor-not-allowed disabled:opacity-40
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
    variants do
      intent do
        standard { [] }
        danger { %w[text-danger-ink hover:bg-danger-surface] }
      end
    end
    defaults { { intent: :standard } }
  end

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-5 py-3 text-sm font-semibold
        text-canvas transition hover:bg-primary-hover focus-visible:outline focus-visible:outline-2
        focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  def render? = checklist.present? || editable?

  def editable?
    relationship_profile.kept? && (!moment.respond_to?(:archived?) || !moment.archived?)
  end

  def anchor_id
    moment.is_a?(EventPlan) ? "personal-touch-checklist" : "personal-touch-#{moment.id}"
  end

  def title_id
    "#{anchor_id}-title"
  end

  def visible_items
    @visible_items ||= checklist.personal_touch_items.to_a.reject(&:dismissed?).sort_by do |item|
      [ item.position, item.created_at, item.id ]
    end
  end

  def progress
    checklist.progress
  end

  def create_path
    if moment.is_a?(EventPlan)
      event_plan_personal_touch_checklist_path(moment)
    else
      relationship_profile_important_date_personal_touch_checklist_path(relationship_profile, moment)
    end
  end

  def item_path(item, action)
    public_send("#{action}_personal_touch_checklist_personal_touch_item_path", checklist, item)
  end

  def source_labels(item)
    item.source_context.filter_map do |source|
      next unless source.is_a?(Hash) && source["source_type"] == "RelationshipPreference"

      certainty = source["certainty"].presence_in(PersonalTouchItem::SOURCE_CERTAINTIES) || "inferred"
      t("personal_touch_checklists.sources.relationship_preference.#{certainty}", label: source["source_label"])
    end
  end
end
