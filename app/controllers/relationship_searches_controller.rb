class RelationshipSearchesController < ApplicationController
  PAGE_SIZE = 20

  def show
    authorize RelationshipProfile, :index?
    owner_profiles = policy_scope(RelationshipProfile)
    query_params = request.post? ? params : ActionController::Parameters.new
    @query = RelationshipMemorySearch::SearchQuery.new(owner_profiles, params: query_params)
    all_results = @query.resolve
    @result_relationship_count = all_results.map(&:relationship_profile).uniq.size
    @pagy, @results = pagy(:offset, all_results, limit: PAGE_SIZE, page: normalized_page(all_results.size))
    @results ||= []
    @grouped_results = @results.group_by(&:relationship_profile)
    @relationship_profiles = owner_profiles.ordered
  end

  private

  def normalized_page(result_count)
    page = Integer(params[:page], exception: false) if params[:page].is_a?(String) || params[:page].is_a?(Integer)
    last_page = [ result_count.fdiv(PAGE_SIZE).ceil, 1 ].max

    page&.between?(1, last_page) ? page : 1
  end
end
