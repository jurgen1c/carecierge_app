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
    [ :friend, "FriendRelationshipProfile" ],
    [ :best_friend, "BestFriendRelationshipProfile" ],
    [ :acquaintance, "AcquaintanceRelationshipProfile" ],
    [ :spouse, "SpouseRelationshipProfile" ],
    [ :partner, "PartnerRelationshipProfile" ],
    [ :fiance, "FianceRelationshipProfile" ],
    [ :fiancee, "FianceeRelationshipProfile" ],
    [ :significant_other, "SignificantOtherRelationshipProfile" ],
    [ :family, "FamilyRelationshipProfile" ],
    [ :mother, "MotherRelationshipProfile" ],
    [ :father, "FatherRelationshipProfile" ],
    [ :parent, "ParentRelationshipProfile" ],
    [ :stepparent, "StepparentRelationshipProfile" ],
    [ :guardian, "GuardianRelationshipProfile" ],
    [ :child, "ChildRelationshipProfile" ],
    [ :son, "SonRelationshipProfile" ],
    [ :daughter, "DaughterRelationshipProfile" ],
    [ :sibling, "SiblingRelationshipProfile" ],
    [ :brother, "BrotherRelationshipProfile" ],
    [ :sister, "SisterRelationshipProfile" ],
    [ :grandparent, "GrandparentRelationshipProfile" ],
    [ :grandmother, "GrandmotherRelationshipProfile" ],
    [ :grandfather, "GrandfatherRelationshipProfile" ],
    [ :grandchild, "GrandchildRelationshipProfile" ],
    [ :aunt, "AuntRelationshipProfile" ],
    [ :uncle, "UncleRelationshipProfile" ],
    [ :cousin, "CousinRelationshipProfile" ],
    [ :niece, "NieceRelationshipProfile" ],
    [ :nephew, "NephewRelationshipProfile" ],
    [ :in_law, "InLawRelationshipProfile" ],
    [ :extended_family, "ExtendedFamilyRelationshipProfile" ],
    [ :boss, "BossRelationshipProfile" ],
    [ :manager, "ManagerRelationshipProfile" ],
    [ :direct_report, "DirectReportRelationshipProfile" ],
    [ :coworker, "CoworkerRelationshipProfile" ],
    [ :mentor, "MentorRelationshipProfile" ],
    [ :mentee, "MenteeRelationshipProfile" ],
    [ :advisor, "AdvisorRelationshipProfile" ],
    [ :colleague, "ColleagueRelationshipProfile" ],
    [ :business_partner, "BusinessPartnerRelationshipProfile" ],
    [ :client, "ClientRelationshipProfile" ],
    [ :customer, "CustomerRelationshipProfile" ],
    [ :vendor, "VendorRelationshipProfile" ],
    [ :neighbor, "NeighborRelationshipProfile" ],
    [ :roommate, "RoommateRelationshipProfile" ],
    [ :housemate, "HousemateRelationshipProfile" ],
    [ :classmate, "ClassmateRelationshipProfile" ],
    [ :teacher, "TeacherRelationshipProfile" ],
    [ :student, "StudentRelationshipProfile" ],
    [ :coach, "CoachRelationshipProfile" ],
    [ :teammate, "TeammateRelationshipProfile" ],
    [ :community_member, "CommunityMemberRelationshipProfile" ],
    [ :caregiver, "CaregiverRelationshipProfile" ],
    [ :care_recipient, "CareRecipientRelationshipProfile" ],
    [ :doctor, "DoctorRelationshipProfile" ],
    [ :therapist, "TherapistRelationshipProfile" ],
    [ :other, "OtherRelationshipProfile" ]
  ].freeze
  TYPE_LABELS = TYPE_OPTIONS.to_h { |label_key, class_name| [ class_name, label_key ] }.freeze
  DEFAULT_TYPE = "FriendRelationshipProfile"
  INVALID_TYPE = "__invalid_relationship_profile_type__"
  CONTACT_FORM_KINDS = %w[email personal_phone business_phone].freeze
  FORM_SLOT_COUNT = 3

  friendly_id :display_name, use: :slugged

  belongs_to :user
  has_many :contact_methods, dependent: :destroy
  has_many :relationship_notes, dependent: :destroy
  has_many :relationship_preferences, dependent: :destroy
  has_many :relationship_tags, dependent: :destroy

  accepts_nested_attributes_for :contact_methods, allow_destroy: true
  accepts_nested_attributes_for :relationship_notes, allow_destroy: true
  accepts_nested_attributes_for :relationship_preferences, allow_destroy: true
  accepts_nested_attributes_for :relationship_tags, allow_destroy: true

  before_validation :default_type

  validates :first_name, presence: true
  validates :type, inclusion: { in: TYPE_LABELS.keys }
  validates_associated :contact_methods, :relationship_notes, :relationship_preferences, :relationship_tags
  validate :unique_nested_preference_keys
  validate :unique_nested_tag_names

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

  def structured_preferences_text
    structured_preferences.map { |key, value| "#{key}: #{value}" }.join("\n")
  end

  def structured_preferences
    relationship_preferences.index_by(&:key).transform_values(&:value)
  end

  def contact_method_for(kind)
    contact_methods.detect { |method| method.kind == kind } || contact_methods.build(kind:)
  end

  def public_note
    relationship_notes.detect { |note| !note.private? } || relationship_notes.build(private: false, category: "General")
  end

  def private_note
    relationship_notes.detect(&:private?) || relationship_notes.build(private: true, category: "Private")
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

  def preference_slots
    fill_slots(relationship_preferences.to_a) { relationship_preferences.build }
  end

  def tag_slots
    fill_slots(relationship_tags.to_a) { relationship_tags.build }
  end

  def prepare_nested_form_associations
    CONTACT_FORM_KINDS.each { |kind| contact_method_for(kind) }
    public_note
    private_note
    preference_slots
    tag_slots
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

  def should_generate_new_friendly_id?
    slug.blank? || first_name_changed? || last_name_changed? || preferred_name_changed?
  end

  private

  def default_type
    self.type = DEFAULT_TYPE if type.blank?
  end

  def unique_nested_preference_keys
    return unless duplicate_nested_value?(relationship_preferences, :key)

    errors.add(:relationship_preferences, "contains duplicate keys")
  end

  def unique_nested_tag_names
    return unless duplicate_nested_value?(relationship_tags, :name)

    errors.add(:relationship_tags, "contains duplicate names")
  end

  def self.type_label_for_key(label_key)
    I18n.t("relationship_profiles.types.#{label_key}")
  end
  private_class_method :type_label_for_key

  def fill_slots(records)
    records.tap do |slots|
      (FORM_SLOT_COUNT - slots.size).times { slots << yield }
    end
  end

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
