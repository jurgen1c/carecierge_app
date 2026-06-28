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
    authorize @relationship_profile
  end

  def edit
  end

  def create
    @relationship_profile = current_user.relationship_profiles.new
    authorize @relationship_profile

    if profile_form.save
      redirect_to @relationship_profile, notice: t(".notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if profile_form.save
      redirect_to @relationship_profile, notice: t(".notice")
    else
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
      .includes(:contact_methods, :relationship_preferences, :relationship_tags)
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
      :notes,
      :private_notes,
      :relationship_type_name,
      :email,
      :phone,
      :structured_preferences_text,
      :tag_names
    )
  end

  def profile_form
    @profile_form ||= RelationshipProfileForm.new(
      profile: @relationship_profile,
      params: relationship_profile_params
    )
  end

  def not_found
    head :not_found
  end
end
