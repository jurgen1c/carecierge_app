class OnboardingController < ApplicationController
  def show
    @relationship_profile = current_user.relationship_profiles.new
    authorize @relationship_profile, :create?
  end

  def create
    @relationship_profile = current_user.relationship_profiles.new(onboarding_relationship_profile_params)
    authorize @relationship_profile, :create?

    if invalid_relationship_type?
      @relationship_profile.errors.add(:type, :inclusion)
      render :show, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @relationship_profile.save!
      current_user.complete_onboarding!
    end

    redirect_to relationship_profile_path(@relationship_profile), notice: t(".notice")
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  def skip
    current_user.skip_onboarding!

    redirect_to dashboard_path, notice: t(".notice")
  end

  private

  def onboarding_relationship_profile_params
    permitted_params = params.require(:relationship_profile).permit(
      :first_name,
      :type,
      :custom_type_label,
      :birthday,
      relationship_preferences_attributes: %i[preference_type category key value confidence]
    )
    sanitize_relationship_type_param(permitted_params)
    sanitize_relationship_preference_enum_params(permitted_params)
    permitted_params
  end

  def sanitize_relationship_type_param(permitted_params)
    return unless permitted_params.key?(:type)
    return if permitted_params[:type].blank?
    return if permitted_params[:type].in?(RelationshipProfile::TYPE_LABELS.keys)

    @invalid_relationship_type = true
    permitted_params.delete(:type)
  end

  def invalid_relationship_type?
    @invalid_relationship_type == true
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
end
