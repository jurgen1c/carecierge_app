module DailyFeed
  Item = Data.define(
    :key,
    :kind,
    :section,
    :title,
    :detail,
    :source_label,
    :source_context,
    :source_certainty,
    :source,
    :relationship_profile,
    :sort_at,
    :action_kind,
    :suggestion
  )
end
