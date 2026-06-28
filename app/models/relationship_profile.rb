class RelationshipProfile < ApplicationRecord
  extend FriendlyId
  include Discard::Model

  friendly_id :display_name, use: :slugged

  belongs_to :user
  has_many :contact_methods, dependent: :destroy
  has_many :relationship_notes, dependent: :destroy
  has_many :relationship_preferences, dependent: :destroy
  has_many :relationship_tags, dependent: :destroy

  attr_writer :email, :phone, :tag_names, :structured_preferences_text

  before_validation :normalize_relationship_type_name

  validates :first_name, presence: true

  scope :active, -> { kept }
  scope :archived, -> { discarded }
  scope :ordered, -> { order(Arel.sql("lower(first_name) ASC"), Arel.sql("lower(last_name) ASC NULLS LAST")) }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def display_name
    preferred_name.presence || full_name
  end

  def archived?
    discarded?
  end

  def archive!
    discard!
  end

  def email
    return @email if defined?(@email)

    contact_methods.find { |method| method.kind == "email" }&.value
  end

  def phone
    return @phone if defined?(@phone)

    contact_methods.find { |method| method.kind == "phone" }&.value
  end

  def tag_names
    return @tag_names if defined?(@tag_names)

    relationship_tags.map(&:name).join(", ")
  end

  def structured_preferences_text
    return @structured_preferences_text if defined?(@structured_preferences_text)

    structured_preferences.map { |key, value| "#{key}: #{value}" }.join("\n")
  end

  def structured_preferences
    relationship_preferences.index_by(&:key).transform_values(&:value)
  end

  def should_generate_new_friendly_id?
    slug.blank? || first_name_changed? || last_name_changed? || preferred_name_changed?
  end

  private

  def normalize_relationship_type_name
    self.relationship_type_name = relationship_type_name.to_s.strip.presence
  end
end
