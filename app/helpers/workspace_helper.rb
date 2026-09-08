module WorkspaceHelper
  LOCALE_QUERY_KEYS = %w[
    q status tag_id group_id page section timeline_type suggestion suggestion_type gesture
    draft_page social_context_page memory_proposal selected_capability capability
    relationship_profile_id tab mode kind risk_level category occasion
  ].freeze

  def workspace_page_kind
    action_name.in?(%w[new edit create update]) ? "form" : "workspace"
  end

  def workspace_locale_path(locale)
    path = request.get? || request.head? ? request.path : dashboard_path
    query = request.query_parameters.slice(*LOCALE_QUERY_KEYS).merge("locale" => locale.to_s)
    "#{path}?#{query.to_query}"
  end

  def workspace_page_title
    return content_for(:title) if content_for?(:title)

    name = t("workspace.pages.#{controller_name}", default: t("workspace.navigation.today"))
    action = action_name.in?(%w[new edit]) ? t("workspace.page_actions.#{action_name}", name:) : name
    "#{action} · Carecierge"
  end
end
