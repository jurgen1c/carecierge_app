class OnboardingController < ApplicationController
  ONBOARDING_PREFERENCE_DEFAULTS = [
    { preference_type: "positive", category: "general", confidence: "medium" },
    { preference_type: "negative", category: "general", confidence: "medium" },
    { preference_type: "constraint", category: "boundaries", confidence: "medium" }
  ].freeze
  ONBOARDING_PREFERENCES_LIMIT = ONBOARDING_PREFERENCE_DEFAULTS.size
  ONBOARDING_IMPORTANT_DATES_LIMIT = 3

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
      relationship_preferences_attributes: %i[preference_type category key value confidence source_notes],
      important_dates_attributes: %i[date_type title starts_on recurrence importance_level reminder_schedule notes]
    )
    limit_onboarding_preference_params(permitted_params)
    limit_onboarding_important_date_params(permitted_params)
    sanitize_relationship_type_param(permitted_params)
    sanitize_relationship_preference_enum_params(permitted_params)
    apply_onboarding_preference_defaults(permitted_params)
    sanitize_important_date_enum_params(permitted_params)
    permitted_params
  end

  def prepare_onboarding_relationship_profile
    prepare_onboarding_preferences
    (ONBOARDING_IMPORTANT_DATES_LIMIT - @relationship_profile.important_dates.size).times do
      @relationship_profile.important_dates.build
    end
  end

  def onboarding_preference_defaults(index)
    ONBOARDING_PREFERENCE_DEFAULTS.fetch(index)
  end

  def prepare_onboarding_preferences
    preferences_by_type = @relationship_profile.relationship_preferences.index_by(&:preference_type)
    ordered_preferences = ONBOARDING_PREFERENCE_DEFAULTS.map do |defaults|
      preferences_by_type[defaults.fetch(:preference_type)] || @relationship_profile.relationship_preferences.build(defaults)
    end

    @relationship_profile.association(:relationship_preferences).target = ordered_preferences
  end

  def limit_onboarding_preference_params(permitted_params)
    preference_params = permitted_params[:relationship_preferences_attributes]
    return if preference_params.blank?

    permitted_params[:relationship_preferences_attributes] =
      if preference_params.is_a?(Array)
        preference_params.first(ONBOARDING_PREFERENCES_LIMIT)
      else
        preference_params.each_pair.first(ONBOARDING_PREFERENCES_LIMIT).to_h
      end
  end

  def limit_onboarding_important_date_params(permitted_params)
    important_date_params = permitted_params[:important_dates_attributes]
    return if important_date_params.blank?

    permitted_params[:important_dates_attributes] =
      if important_date_params.is_a?(Array)
        important_date_params.first(ONBOARDING_IMPORTANT_DATES_LIMIT)
      else
        important_date_params.each_pair.first(ONBOARDING_IMPORTANT_DATES_LIMIT).to_h
      end
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

  def apply_onboarding_preference_defaults(permitted_params)
    each_nested_attribute(permitted_params.fetch(:relationship_preferences_attributes, {})).with_index do |preference_params, index|
      defaults = onboarding_preference_defaults(index)
      assign_nested_value(preference_params, :preference_type, defaults.fetch(:preference_type))
      apply_nested_default(preference_params, :category, defaults.fetch(:category))
      assign_nested_value(preference_params, :confidence, defaults.fetch(:confidence))
      assign_nested_value(preference_params, :source_notes, t("onboarding.show.preference_source_notes_default")) if onboarding_preference_present?(preference_params)
    end
  end

  def onboarding_preference_present?(preference_params)
    preference_params[:key].present? || preference_params["key"].present? || preference_params[:value].present? || preference_params["value"].present?
  end

  def apply_nested_default(nested_params, key, default_value)
    nested_key = nested_params.key?(key) ? key : key.to_s
    return if nested_params.key?(nested_key) && nested_params[nested_key].nil?

    nested_params[nested_key] = default_value if nested_params[nested_key].blank?
  end

  def assign_nested_value(nested_params, key, value)
    nested_key = nested_params.key?(key) ? key : key.to_s

    nested_params[nested_key] = value
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
    return [].each if attributes.blank?

    records = attributes.respond_to?(:each_value) ? attributes.each_value : attributes

    return records.each unless block_given?

    records.each(&)
  end

  def sanitize_relationship_preference_enum(preference_params, key, allowed_values)
    sanitize_nested_enum(preference_params, key, allowed_values.keys)
  end

  def sanitize_nested_enum(nested_params, key, allowed_values)
    nested_key = nested_params.key?(key) ? key : key.to_s
    return unless nested_params.key?(nested_key)
    return if nested_params[nested_key].blank?
    return if nested_params[nested_key].in?(allowed_values)

    nested_params[nested_key] = nil
  end
end
