class RelationshipProfilesController < ApplicationController
  before_action :set_relationship_profile, only: %i[show edit update archive destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    authorize RelationshipProfile
    query = RelationshipProfile::SearchQuery.new(
      policy_scope(RelationshipProfile).includes(:relationship_tags),
      params:
    )

    @relationship_profiles = query.resolve
    @search_params = query.search_params
    @search_query = query.search_query
    @q = query.ransack
    @status = query.status
  end

  def show
  end

  def new
    @relationship_profile = current_user.relationship_profiles.new
    @relationship_profile.prepare_nested_form_associations
    authorize @relationship_profile
  end

  def edit
    @relationship_profile.prepare_nested_form_associations
  end

  def create
    @relationship_profile = current_user.relationship_profiles.new(relationship_profile_params)
    authorize @relationship_profile

    if @relationship_profile.save
      redirect_to relationship_profile_path(@relationship_profile), notice: t(".notice")
    else
      @relationship_profile.prepare_nested_form_associations
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @relationship_profile.assign_attributes(relationship_profile_params)

    if @relationship_profile.save
      redirect_to relationship_profile_path(@relationship_profile), notice: t(".notice")
    else
      @relationship_profile.prepare_nested_form_associations
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
    @relationship_profile = authorize current_user
      .relationship_profiles
      .includes(:contact_methods, :relationship_notes, :relationship_preferences, :relationship_tags)
      .friendly
      .find(params[:id])
  end

  def relationship_profile_params
    params.require(:relationship_profile).permit(
      :first_name,
      :last_name,
      :preferred_name,
      :pronouns,
      :birthday,
      :type,
      contact_methods_attributes: %i[id kind value label preferred _destroy],
      relationship_notes_attributes: %i[id category private body _destroy],
      relationship_preferences_attributes: %i[id key value _destroy],
      relationship_tags_attributes: %i[id name _destroy]
    )
  end

  def not_found
    head :not_found
  end
end
