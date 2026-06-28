class RelationshipProfile::SearchQuery < ApplicationQuery
  SEARCH_PREDICATE = "first_name_or_last_name_or_preferred_name_or_notes_or_relationship_type_name_cont"
  STATUSES = %w[active archived all].freeze

  attr_reader :ransack, :search_params, :status

  def initialize(relation = RelationshipProfile.all, params:)
    super(relation)
    @params = params
    @search_params = build_search_params
    @status = build_status
  end

  def resolve
    @ransack = filtered_relation.ransack(search_params)
    ransack.result.ordered
  end

  def search_query
    search_params[SEARCH_PREDICATE]
  end

  private

  attr_reader :params

  def filtered_relation
    case status
    when "archived"
      relation.archived
    when "all"
      relation
    else
      relation.active
    end
  end

  def build_status
    params[:status].presence_in(STATUSES) || "active"
  end

  def build_search_params
    return {} unless params[:q].respond_to?(:permit)

    params[:q].permit(SEARCH_PREDICATE).to_h
  end
end
