class RelationshipProfile::SearchQuery < ApplicationQuery
  SEARCH_PREDICATE = "first_name_or_last_name_or_preferred_name_or_notes_or_type_cont"
  STATUSES = %w[active archived all].freeze

  attr_reader :ransack, :search_params, :status

  def initialize(relation = RelationshipProfile.all, params:)
    super(relation)
    @params = params
    @search_params = build_search_params
    @status = build_status
  end

  def resolve
    @ransack = searched_relation.ransack({})
    ransack.result.ordered
  end

  def search_query
    search_params[SEARCH_PREDICATE]
  end

  private

  attr_reader :params

  def searched_relation
    return filtered_relation if search_query.blank?

    filtered_relation.where(search_condition)
  end

  def search_condition
    profile_table = RelationshipProfile.arel_table
    notes_table = RelationshipNote.arel_table
    rich_text_table = ActionText::RichText.arel_table
    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_query.downcase)}%"

    [
      lower(profile_table[:first_name]).matches(term),
      lower(profile_table[:last_name]).matches(term),
      lower(profile_table[:preferred_name]).matches(term),
      relationship_type_condition(profile_table, term),
      matching_rich_text_exists(profile_table, notes_table, rich_text_table, term)
    ].reduce(&:or)
  end

  def relationship_type_condition(profile_table, term)
    condition = lower(profile_table[:type]).matches(term)
    matching_type_classes = RelationshipProfile.type_classes_matching_label(search_query)

    return condition if matching_type_classes.empty?

    condition.or(profile_table[:type].in(matching_type_classes))
  end

  def lower(attribute)
    Arel::Nodes::NamedFunction.new("LOWER", [ attribute ])
  end

  def matching_rich_text_exists(profile_table, notes_table, rich_text_table, term)
    notes_table
      .project(Arel.sql("1"))
      .join(rich_text_table)
      .on(
        rich_text_table[:record_type].eq("RelationshipNote")
          .and(rich_text_table[:record_id].eq(notes_table[:id]))
          .and(rich_text_table[:name].eq("body"))
      )
      .where(notes_table[:relationship_profile_id].eq(profile_table[:id]))
      .where(lower(rich_text_table[:body]).matches(term))
      .exists
  end

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
