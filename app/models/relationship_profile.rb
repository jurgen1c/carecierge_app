# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id             :uuid             not null, primary key
#  birthday       :date
#  discarded_at   :datetime
#  first_name     :string           not null
#  last_name      :string
#  preferred_name :string
#  pronouns       :string
#  slug           :string
#  type           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name                (first_name)
#  index_relationship_profiles_on_last_name                 (last_name)
#  index_relationship_profiles_on_preferred_name            (preferred_name)
#  index_relationship_profiles_on_slug                      (slug) UNIQUE
#  index_relationship_profiles_on_type                      (type)
#  index_relationship_profiles_on_user_id                   (user_id)
#  index_relationship_profiles_on_user_id_and_discarded_at  (user_id,discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class RelationshipProfile < ApplicationRecord
  extend FriendlyId
  include Discard::Model

  TYPE_OPTIONS = [
    [ :friend, "RelationshipProfiles::Friend" ],
    [ :best_friend, "RelationshipProfiles::BestFriend" ],
    [ :acquaintance, "RelationshipProfiles::Acquaintance" ],
    [ :spouse, "RelationshipProfiles::Spouse" ],
    [ :partner, "RelationshipProfiles::Partner" ],
    [ :fiance, "RelationshipProfiles::Fiance" ],
    [ :fiancee, "RelationshipProfiles::Fiancee" ],
    [ :significant_other, "RelationshipProfiles::SignificantOther" ],
    [ :family, "RelationshipProfiles::Family" ],
    [ :mother, "RelationshipProfiles::Mother" ],
    [ :father, "RelationshipProfiles::Father" ],
    [ :parent, "RelationshipProfiles::Parent" ],
    [ :stepparent, "RelationshipProfiles::Stepparent" ],
    [ :guardian, "RelationshipProfiles::Guardian" ],
    [ :child, "RelationshipProfiles::Child" ],
    [ :son, "RelationshipProfiles::Son" ],
    [ :daughter, "RelationshipProfiles::Daughter" ],
    [ :sibling, "RelationshipProfiles::Sibling" ],
    [ :brother, "RelationshipProfiles::Brother" ],
    [ :sister, "RelationshipProfiles::Sister" ],
    [ :grandparent, "RelationshipProfiles::Grandparent" ],
    [ :grandmother, "RelationshipProfiles::Grandmother" ],
    [ :grandfather, "RelationshipProfiles::Grandfather" ],
    [ :grandchild, "RelationshipProfiles::Grandchild" ],
    [ :aunt, "RelationshipProfiles::Aunt" ],
    [ :uncle, "RelationshipProfiles::Uncle" ],
    [ :cousin, "RelationshipProfiles::Cousin" ],
    [ :niece, "RelationshipProfiles::Niece" ],
    [ :nephew, "RelationshipProfiles::Nephew" ],
    [ :in_law, "RelationshipProfiles::InLaw" ],
    [ :extended_family, "RelationshipProfiles::ExtendedFamily" ],
    [ :boss, "RelationshipProfiles::Boss" ],
    [ :manager, "RelationshipProfiles::Manager" ],
    [ :direct_report, "RelationshipProfiles::DirectReport" ],
    [ :coworker, "RelationshipProfiles::Coworker" ],
    [ :mentor, "RelationshipProfiles::Mentor" ],
    [ :mentee, "RelationshipProfiles::Mentee" ],
    [ :advisor, "RelationshipProfiles::Advisor" ],
    [ :colleague, "RelationshipProfiles::Colleague" ],
    [ :business_partner, "RelationshipProfiles::BusinessPartner" ],
    [ :client, "RelationshipProfiles::Client" ],
    [ :customer, "RelationshipProfiles::Customer" ],
    [ :vendor, "RelationshipProfiles::Vendor" ],
    [ :neighbor, "RelationshipProfiles::Neighbor" ],
    [ :roommate, "RelationshipProfiles::Roommate" ],
    [ :housemate, "RelationshipProfiles::Housemate" ],
    [ :classmate, "RelationshipProfiles::Classmate" ],
    [ :teacher, "RelationshipProfiles::Teacher" ],
    [ :student, "RelationshipProfiles::Student" ],
    [ :coach, "RelationshipProfiles::Coach" ],
    [ :teammate, "RelationshipProfiles::Teammate" ],
    [ :community_member, "RelationshipProfiles::CommunityMember" ],
    [ :caregiver, "RelationshipProfiles::Caregiver" ],
    [ :care_recipient, "RelationshipProfiles::CareRecipient" ],
    [ :doctor, "RelationshipProfiles::Doctor" ],
    [ :therapist, "RelationshipProfiles::Therapist" ],
    [ :other, "RelationshipProfiles::Other" ]
  ].freeze
  TYPE_LABELS = TYPE_OPTIONS.to_h { |label_key, class_name| [ class_name, label_key ] }.freeze
  DEFAULT_TYPE = "RelationshipProfiles::Friend"
  INVALID_TYPE = "__invalid_relationship_profile_type__"

  friendly_id :display_name, use: :slugged

  belongs_to :user
  has_many :contact_methods, dependent: :destroy
  has_many :relationship_notes, dependent: :destroy
  has_many :relationship_preferences, dependent: :destroy
  has_many :relationship_tags, dependent: :destroy
  has_many :relationship_field_values, dependent: :destroy

  accepts_nested_attributes_for :contact_methods, allow_destroy: true
  accepts_nested_attributes_for :relationship_notes, allow_destroy: true
  accepts_nested_attributes_for :relationship_preferences, allow_destroy: true
  accepts_nested_attributes_for :relationship_tags, allow_destroy: true
  accepts_nested_attributes_for :relationship_field_values, allow_destroy: true

  before_validation :default_type

  validates :first_name, presence: true
  validates :type, inclusion: { in: TYPE_LABELS.keys }
  validates_associated :contact_methods, :relationship_notes, :relationship_preferences, :relationship_tags, :relationship_field_values
  validate :unique_nested_contact_kinds
  validate :unique_nested_preference_keys
  validate :unique_nested_tag_names
  validate :unique_nested_template_fields
  validate :unique_nested_custom_field_labels

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

  def relationship_type_label
    self.class.type_label(type.presence || DEFAULT_TYPE)
  end

  def self.type_options
    TYPE_OPTIONS.map { |label_key, class_name| [ type_label_for_key(label_key), class_name ] }
  end

  def self.type_label(class_name)
    type_label_for_key(TYPE_LABELS.fetch(class_name))
  end

  def self.type_classes_matching_label(query)
    term = query.to_s.downcase
    TYPE_OPTIONS.filter_map do |label_key, class_name|
      class_name if type_label_for_key(label_key).downcase.include?(term)
    end
  end

  def self.policy_class
    RelationshipProfilePolicy
  end

  def archive!
    discard!
  end

  def email
    contact_methods.find { |method| %w[email personal_email business_email].include?(method.kind) }&.value
  end

  def phone
    contact_methods.find { |method| %w[phone personal_phone business_phone].include?(method.kind) }&.value
  end

  def tag_names
    relationship_tags.map(&:name).join(", ")
  end

  def visible_relationship_field_values
    relationship_field_values.reject(&:marked_for_destruction?).reject(&:hidden?).select do |field_value|
      field_value.value.present? && current_relationship_field_value?(field_value)
    end.sort_by do |field_value|
      [ field_value.position || 0, field_value.display_label.downcase ]
    end
  end

  def structured_preferences_text
    structured_preferences.map { |key, value| "#{key}: #{value}" }.join("\n")
  end

  def structured_preferences
    relationship_preferences.index_by(&:key).transform_values(&:value)
  end

  def public_notes
    relationship_notes.reject(&:private?)
  end

  def private_notes
    relationship_notes.select(&:private?)
  end

  def public_notes_preview
    public_notes.map { |note| note.body.to_plain_text }.compact_blank.join(" ")
  end

  def contact_methods_attributes=(attributes)
    super(reject_blank_new_nested_attributes(attributes) { |nested_attributes| nested_attributes["value"].blank? })
  end

  def relationship_notes_attributes=(attributes)
    super(
      reject_blank_new_nested_attributes(attributes) do |nested_attributes|
        ActionText::Content.new(nested_attributes["body"].to_s).to_plain_text.blank?
      end
    )
  end

  def relationship_preferences_attributes=(attributes)
    super(
      reject_blank_new_nested_attributes(attributes) do |nested_attributes|
        nested_attributes["key"].blank? && nested_attributes["value"].blank?
      end
    )
  end

  def relationship_tags_attributes=(attributes)
    super(reject_blank_new_nested_attributes(attributes) { |nested_attributes| nested_attributes["name"].blank? })
  end

  def relationship_field_values_attributes=(attributes)
    super(
      reject_blank_new_nested_attributes(attributes) do |nested_attributes|
        if nested_attributes["template_field_id"].present?
          nested_attributes["value"].blank? && nested_attributes["hidden"] != "1"
        else
          nested_attributes["label"].blank? && nested_attributes["value"].blank? && nested_attributes["hidden"] != "1"
        end
      end
    )
  end

  def should_generate_new_friendly_id?
    slug.blank? || first_name_changed? || last_name_changed? || preferred_name_changed?
  end

  private

  def default_type
    self.type = DEFAULT_TYPE if type.blank?
  end

  def unique_nested_contact_kinds
    return unless duplicate_nested_value?(contact_methods, :kind)

    errors.add(:contact_methods, "contains duplicate kinds")
  end

  def unique_nested_preference_keys
    return unless duplicate_nested_value?(relationship_preferences, :key)

    errors.add(:relationship_preferences, "contains duplicate keys")
  end

  def unique_nested_tag_names
    return unless duplicate_nested_value?(relationship_tags, :name)

    errors.add(:relationship_tags, "contains duplicate names")
  end

  def unique_nested_template_fields
    suggested_field_values = relationship_field_values.select { |field_value| field_value.template_field_id.present? }
    return unless duplicate_nested_value?(suggested_field_values, :template_field_id)

    errors.add(:relationship_field_values, :duplicate_suggested_fields)
  end

  def unique_nested_custom_field_labels
    custom_field_values = relationship_field_values.select { |field_value| field_value.template_field_id.blank? }
    return unless duplicate_nested_value?(custom_field_values, :label)

    errors.add(:relationship_field_values, :duplicate_labels)
  end

  def current_relationship_field_value?(field_value)
    return true if field_value.custom?
    return true unless relationship_type_template_available?

    field_value.template_field&.relationship_template&.relationship_type == type
  end

  def relationship_type_template_available?
    return @relationship_type_template_available if defined?(@relationship_type_template_available)

    @relationship_type_template_available = RelationshipTemplate.for_relationship_type(type).present?
  end

  def self.type_label_for_key(label_key)
    I18n.t("relationship_profiles.types.#{label_key}")
  end
  private_class_method :type_label_for_key

  def reject_blank_new_nested_attributes(attributes)
    attributes.to_h.reject do |_index, nested_attributes|
      nested_attributes["id"].blank? && yield(nested_attributes)
    end
  end

  def duplicate_nested_value?(records, attribute)
    normalized_values = records.reject(&:marked_for_destruction?).filter_map do |record|
      value = record.public_send(attribute).to_s.strip.downcase
      value.presence
    end

    normalized_values.uniq.size != normalized_values.size
  end
end
