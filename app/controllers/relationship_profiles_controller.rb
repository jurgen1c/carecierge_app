class RelationshipProfilesController < ApplicationController
  before_action :set_relationship_profile, only: %i[show edit update archive destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    authorize RelationshipProfile
    query = RelationshipProfile::SearchQuery.new(
      policy_scope(RelationshipProfile).includes(:relationship_tags, :relationship_groups, relationship_notes: :rich_text_body),
      params:
    )

    @relationship_profiles = query.resolve
    @search_params = query.search_params
    @search_query = query.search_query
    @q = query.ransack
    @status = query.status
    @tag_id = query.tag_id
    @group_id = query.group_id
    @relationship_tags = current_user.relationship_tags.ordered
    @relationship_groups = current_user.relationship_groups.ordered
  end

  def show
    @timeline_type = params[:timeline_type].to_s.in?(TimelineEntry::ENTRY_TYPES) ? params[:timeline_type].to_s : nil
    @relationship_reminders = @relationship_profile.reminders.active.by_effective_delivery.limit(5).to_a
    @interactions = @relationship_profile.interactions.includes(:source).ordered.limit(10).to_a
  end

  def new
    @relationship_profile = current_user.relationship_profiles.new
    authorize @relationship_profile
    prepare_relationship_profile_form
  end

  def edit
    prepare_relationship_profile_form
  end

  def create
    @relationship_profile = current_user.relationship_profiles.new
    @relationship_profile.assign_attributes(relationship_profile_params)
    authorize @relationship_profile

    if @relationship_profile.save
      redirect_to relationship_profile_path(@relationship_profile), notice: t(".notice")
    else
      prepare_relationship_profile_form
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @relationship_profile.assign_attributes(relationship_profile_params)

    if @relationship_profile.save
      redirect_to relationship_profile_path(@relationship_profile), notice: t(".notice")
    else
      prepare_relationship_profile_form
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @relationship_profile.archive!

    redirect_to relationship_profiles_path, notice: t(".notice")
  end

  def destroy
    @relationship_profile.destroy!

    redirect_to relationship_profiles_path, notice: t(".notice")
  end

  private

  def set_relationship_profile
    @relationship_profile = current_user
      .relationship_profiles
      .includes(
        :contact_methods,
        :gifts,
        :important_dates,
        :contact_cadence,
        { commitments: :reminders },
        :relationship_preferences,
        :relationship_tags,
        :relationship_groups,
        desires: :fulfillments,
        relationship_taggings: :relationship_tag,
        relationship_group_memberships: :relationship_group,
        relationship_field_values: { template_field: :relationship_template },
        relationship_notes: :rich_text_body
      )
      .friendly
      .find(params[:id])
    authorize @relationship_profile
  end

  def relationship_profile_params
    permitted_params = params.require(:relationship_profile).permit(
      :first_name,
      :last_name,
      :preferred_name,
      :pronouns,
      :birthday,
      :type,
      :custom_type_label,
      contact_methods_attributes: %i[id kind value label preferred _destroy],
      relationship_notes_attributes: %i[id category private body _destroy],
      relationship_preferences_attributes: %i[id preference_type category key value confidence learned_on source_notes _destroy],
      relationship_tags_attributes: %i[id name _destroy],
      relationship_groups_attributes: %i[id name _destroy],
      relationship_field_values_attributes: %i[id template_field_id key label value hidden custom position _destroy]
    )
    sanitize_discriminator_params(permitted_params)
  end

  def prepare_relationship_profile_form
    @relationship_profile_form = RelationshipProfiles::FormState.new(@relationship_profile).prepare!
  end

  def sanitize_discriminator_params(permitted_params)
    sanitize_relationship_type_param(permitted_params)
    sanitize_contact_method_kind_params(permitted_params)
    sanitize_relationship_preference_enum_params(permitted_params)

    permitted_params
  end

  def sanitize_relationship_type_param(permitted_params)
    return unless permitted_params.key?(:type)
    return if permitted_params[:type].blank?
    return if permitted_params[:type].in?(RelationshipProfile::TYPE_LABELS.keys)

    permitted_params[:type] = RelationshipProfile::INVALID_TYPE
  end

  def sanitize_contact_method_kind_params(permitted_params)
    each_nested_attribute(permitted_params.fetch(:contact_methods_attributes, {})) do |contact_method_params|
      next unless contact_method_params.key?(:kind)
      next if contact_method_params[:kind].in?(ContactMethod.kinds.keys)

      contact_method_params[:kind] = nil
    end
  end

  def sanitize_relationship_preference_enum_params(permitted_params)
    each_nested_attribute(permitted_params.fetch(:relationship_preferences_attributes, {})) do |preference_params|
      sanitize_relationship_preference_enum(preference_params, :preference_type, RelationshipPreference.preference_types)
      sanitize_relationship_preference_enum(preference_params, :category, RelationshipPreference.categories)
      sanitize_relationship_preference_enum(preference_params, :confidence, RelationshipPreference.confidences)
    end
  end

  def each_nested_attribute(attributes, &)
    return if attributes.blank?

    records = attributes.respond_to?(:each_value) ? attributes.each_value : attributes

    records.each(&)
  end

  def sanitize_relationship_preference_enum(preference_params, key, allowed_values)
    return unless preference_params.key?(key)
    return if preference_params[key].blank?
    return if preference_params[key].in?(allowed_values.keys)

    preference_params[key] = nil
  end

  def not_found
    head :not_found
  end
end
