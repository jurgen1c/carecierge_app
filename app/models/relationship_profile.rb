# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  archived_at            :datetime
#  birthday               :date
#  first_name             :string           not null
#  last_name              :string
#  notes                  :text
#  preferred_name         :string
#  private_notes          :text
#  pronouns               :string
#  structured_preferences :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  relationship_type_id   :uuid
#  user_id                :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name               (first_name)
#  index_relationship_profiles_on_last_name                (last_name)
#  index_relationship_profiles_on_preferred_name           (preferred_name)
#  index_relationship_profiles_on_relationship_type_id     (relationship_type_id)
#  index_relationship_profiles_on_user_id                  (user_id)
#  index_relationship_profiles_on_user_id_and_archived_at  (user_id,archived_at)
#
# Foreign Keys
#
#  fk_rails_...                         (relationship_type_id => relationship_types.id)
#  fk_rails_...                         (user_id => users.id)
#  fk_relationship_profiles_type_owner  ([relationship_type_id, user_id] => relationship_types[id, user_id])
#
class RelationshipProfile < ApplicationRecord
  belongs_to :user
  belongs_to :relationship_type, optional: true
  has_many :contact_methods, dependent: :destroy
  has_many :relationship_notes, dependent: :destroy
  has_many :relationship_tags, dependent: :destroy

  attr_writer :relationship_type_name, :email, :phone, :tag_names, :structured_preferences_text

  validates :first_name, presence: true
  validate :relationship_type_owned_by_user

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(Arel.sql("lower(first_name) ASC"), Arel.sql("lower(last_name) ASC NULLS LAST")) }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def display_name
    preferred_name.presence || full_name
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def relationship_type_name
    return @relationship_type_name if defined?(@relationship_type_name)

    relationship_type&.name
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

  private

  def relationship_type_owned_by_user
    return if relationship_type.blank? || user.blank?
    return if relationship_type.user_id == user_id

    errors.add(:relationship_type, :invalid)
  end
end
