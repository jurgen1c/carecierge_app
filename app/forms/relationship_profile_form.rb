class RelationshipProfileForm
  PROFILE_ATTRIBUTES = %i[
    first_name
    last_name
    preferred_name
    pronouns
    birthday
    notes
    private_notes
    relationship_type_name
  ].freeze

  VIRTUAL_ATTRIBUTES = %i[email phone structured_preferences_text tag_names].freeze

  def initialize(profile:, params:)
    @profile = profile
    @params = params
  end

  def save
    assign_submitted_attributes

    ApplicationRecord.transaction do
      profile.save!
      sync_contact_method(:email)
      sync_contact_method(:phone)
      sync_preferences
      sync_tags
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  attr_reader :profile, :params

  def assign_submitted_attributes
    profile.assign_attributes(params.slice(*PROFILE_ATTRIBUTES))

    VIRTUAL_ATTRIBUTES.each do |attribute|
      profile.public_send("#{attribute}=", params[attribute]) if submitted?(attribute)
    end
  end

  def submitted?(attribute)
    params.key?(attribute.to_s)
  end

  def sync_contact_method(kind)
    return unless submitted?(kind)

    value = params[kind].to_s.strip
    contact_method = profile.contact_methods.find_or_initialize_by(kind:)
    new_contact_method = contact_method.new_record?

    if value.present?
      contact_method.assign_attributes(value:, preferred: new_contact_method ? true : contact_method.preferred)
      contact_method.save!
    elsif contact_method.persisted?
      contact_method.destroy!
    end
  end

  def sync_preferences
    return unless submitted?(:structured_preferences_text)

    preferences = parsed_preferences
    normalized_keys = preferences.keys.map(&:downcase)
    destroy_unmatched_preferences(normalized_keys)

    preferences.each do |key, value|
      preference = profile.relationship_preferences.where("lower(key) = ?", key.downcase).first_or_initialize
      preference.update!(key:, value:)
    end
  end

  def parsed_preferences
    params[:structured_preferences_text].to_s.each_line.filter_map do |line|
      key, value = line.split(":", 2).map { |part| part.to_s.strip }
      [ key, value ] if key.present? && value.present?
    end.to_h
  end

  def sync_tags
    return unless submitted?(:tag_names)

    names = params[:tag_names].to_s.split(",").map(&:strip).compact_blank
    names = names.index_by { |name| name.downcase }.values
    normalized_names = names.map(&:downcase)
    destroy_unmatched_tags(normalized_names)

    names.each do |name|
      tag = profile.relationship_tags.where("lower(name) = ?", name.downcase).first_or_initialize
      tag.update!(name:)
    end
  end

  def destroy_unmatched_preferences(normalized_keys)
    return profile.relationship_preferences.destroy_all if normalized_keys.empty?

    profile.relationship_preferences.where.not("lower(key) IN (?)", normalized_keys).destroy_all
  end

  def destroy_unmatched_tags(normalized_names)
    return profile.relationship_tags.destroy_all if normalized_names.empty?

    profile.relationship_tags.where.not("lower(name) IN (?)", normalized_names).destroy_all
  end
end
