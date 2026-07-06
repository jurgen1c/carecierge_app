class OnboardingController < ApplicationController
  def show
    @relationship_profile = current_user.relationship_profiles.new
    prepare_onboarding_relationship_profile
    authorize @relationship_profile, :create?
  end

  def create
    @relationship_profile = current_user.relationship_profiles.new(onboarding_relationship_profile_params)
    authorize @relationship_profile, :create?

    if invalid_relationship_type?
      @relationship_profile.errors.add(:type, :inclusion)
      prepare_onboarding_relationship_profile
      render :show, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      @relationship_profile.save!
      current_user.complete_onboarding!
    end

    redirect_to relationship_profile_path(@relationship_profile), notice: t(".notice")
  rescue ActiveRecord::RecordInvalid
    prepare_onboarding_relationship_profile
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
      relationship_preferences_attributes: %i[preference_type category key value confidence],
      important_dates_attributes: %i[date_type title starts_on recurrence importance_level reminder_schedule notes]
    )
    sanitize_relationship_type_param(permitted_params)
    sanitize_relationship_preference_enum_params(permitted_params)
    sanitize_important_date_enum_params(permitted_params)
    permitted_params
  end

  def prepare_onboarding_relationship_profile
    @relationship_profile.relationship_preferences.build if @relationship_profile.relationship_preferences.empty?
    (3 - @relationship_profile.important_dates.size).times { @relationship_profile.important_dates.build }
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

  def sanitize_important_date_enum_params(permitted_params)
    each_nested_attribute(permitted_params.fetch(:important_dates_attributes, {})) do |important_date_params|
      sanitize_nested_enum(important_date_params, :date_type, ImportantDate::DATE_TYPES)
      sanitize_nested_enum(important_date_params, :recurrence, ImportantDate::RECURRENCES)
      sanitize_nested_enum(important_date_params, :importance_level, ImportantDate::IMPORTANCE_LEVELS)
      sanitize_nested_enum(important_date_params, :reminder_schedule, ImportantDate::REMINDER_SCHEDULES)
    end
  end

  def each_nested_attribute(attributes, &)
    return if attributes.blank?

    records = attributes.respond_to?(:each_value) ? attributes.each_value : attributes

    records.each(&)
  end

  def sanitize_relationship_preference_enum(preference_params, key, allowed_values)
    sanitize_nested_enum(preference_params, key, allowed_values.keys)
  end

  def sanitize_nested_enum(nested_params, key, allowed_values)
    return unless nested_params.key?(key)
    return if nested_params[key].blank?
    return if nested_params[key].in?(allowed_values)

    nested_params[key] = nil
  end
end
