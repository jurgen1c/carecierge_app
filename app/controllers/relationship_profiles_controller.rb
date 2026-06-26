class RelationshipProfilesController < ApplicationController
  SEARCH_PREDICATE = "first_name_or_last_name_or_preferred_name_or_notes_or_relationship_type_name_cont"

  before_action :authenticate_user!
  before_action :set_relationship_profile, only: %i[show edit update archive destroy]

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def index
    authorize RelationshipProfile
    scoped_profiles = filter_by_status(policy_scope(RelationshipProfile).includes(:relationship_type, :relationship_tags))
    @search_params = relationship_search_params
    @search_query = @search_params[SEARCH_PREDICATE]
    @q = scoped_profiles.ransack(@search_params)
    @relationship_profiles = @q.result.ordered
    @status = status_filter
  end

  def show
    authorize @relationship_profile
  end

  def new
    @relationship_profile = current_user.relationship_profiles.new
    authorize @relationship_profile
  end

  def edit
    authorize @relationship_profile
  end

  def create
    @relationship_profile = current_user.relationship_profiles.new(profile_attributes)
    authorize @relationship_profile

    if save_profile(@relationship_profile)
      redirect_to @relationship_profile, notice: t(".notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @relationship_profile
    @relationship_profile.assign_attributes(profile_attributes)

    if save_profile(@relationship_profile)
      redirect_to @relationship_profile, notice: t(".notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    authorize @relationship_profile
    @relationship_profile.archive!

    redirect_to relationship_profiles_path, notice: t(".notice")
  end

  def destroy
    authorize @relationship_profile
    @relationship_profile.destroy!

    redirect_to relationship_profiles_path, notice: t(".notice")
  end

  private

  def set_relationship_profile
    @relationship_profile = policy_scope(RelationshipProfile).includes(:relationship_type, :contact_methods, :relationship_tags).find(params[:id])
  end

  def filter_by_status(scope)
    case status_filter
    when "archived"
      scope.archived
    when "all"
      scope
    else
      scope.active
    end
  end

  def status_filter
    params[:status].presence_in(%w[active archived all]) || "active"
  end

  def relationship_search_params
    return {} unless params[:q].respond_to?(:permit)

    params[:q].permit(SEARCH_PREDICATE).to_h
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

  def profile_attributes
    relationship_profile_params.except(
      :relationship_type_name,
      :email,
      :phone,
      :structured_preferences_text,
      :tag_names
    )
  end

  def save_profile(profile)
    assign_virtual_form_fields(profile)

    ActiveRecord::Base.transaction do
      assign_relationship_type(profile) if profile_param?(:relationship_type_name)
      profile.structured_preferences = structured_preferences if profile_param?(:structured_preferences_text)
      profile.save!
      sync_contact_method(profile, "email", relationship_profile_params[:email]) if profile_param?(:email)
      sync_contact_method(profile, "phone", relationship_profile_params[:phone]) if profile_param?(:phone)
      sync_tags(profile) if profile_param?(:tag_names)
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def assign_virtual_form_fields(profile)
    %i[relationship_type_name email phone structured_preferences_text tag_names].each do |key|
      profile.public_send("#{key}=", relationship_profile_params[key]) if profile_param?(key)
    end
  end

  def assign_relationship_type(profile)
    type_name = relationship_profile_params[:relationship_type_name].to_s.strip
    profile.relationship_type =
      if type_name.present?
        current_user.relationship_types.where("lower(name) = ?", type_name.downcase).first_or_initialize(name: type_name)
      end
  end

  def profile_param?(key)
    relationship_profile_params.key?(key.to_s)
  end

  def sync_contact_method(profile, kind, value)
    contact_method = profile.contact_methods.find_or_initialize_by(kind:)
    new_contact_method = contact_method.new_record?
    value = value.to_s.strip

    if value.present?
      contact_method.value = value
      contact_method.preferred = true if new_contact_method
      contact_method.save!
    elsif contact_method.persisted?
      contact_method.destroy!
    end
  end

  def sync_tags(profile)
    names = relationship_profile_params[:tag_names].to_s.split(",").map(&:strip).compact_blank
    names = names.index_by { |name| name.downcase }.values
    normalized_names = names.map(&:downcase)

    if normalized_names.any?
      profile.relationship_tags.where.not("lower(name) IN (?)", normalized_names).destroy_all
    else
      profile.relationship_tags.destroy_all
    end

    names.each do |name|
      profile.relationship_tags.where("lower(name) = ?", name.downcase).first_or_create!(name:)
    end
  end

  def structured_preferences
    relationship_profile_params[:structured_preferences_text].to_s.each_line.filter_map do |line|
      key, value = line.split(":", 2).map { |part| part.to_s.strip }
      [ key, value ] if key.present? && value.present?
    end.to_h
  end

  def not_found
    head :not_found
  end
end
