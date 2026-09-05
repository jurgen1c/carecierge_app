class ProfessionalContextComponent < ApplicationViewComponent
  option :relationship_profile
  option :form, default: -> { nil }

  style :input do
    base { %w[mt-2 min-h-11 w-full rounded-lg border border-private-line bg-canvas px-3 py-2 text-base text-ink focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20] }
  end

  style :link do
    base { %w[inline-flex min-h-11 items-center font-semibold text-primary underline focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary] }
  end

  def source_options(collection)
    context = relationship_profile.work_context
    scope = context.candidates(collection)
    recent_ids = scope.reorder(created_at: :desc, id: :desc).limit(100).select(:id)
    scope.where(id: recent_ids).or(scope.where(id: Array(relationship_profile.professional_context[collection]).compact_blank)).reorder(created_at: :desc, id: :desc)
  end

  def source_label(record)
    relationship_profile.work_context.label(record)
  end
end
