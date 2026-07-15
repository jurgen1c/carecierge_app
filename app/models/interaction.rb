# == Schema Information
#
# Table name: interactions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  interaction_type        :string           not null
#  notes                   :text
#  occurred_at             :datetime         not null
#  origin                  :string           default("manual"), not null
#  source_type             :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  source_id               :uuid
#
# Indexes
#
#  idx_on_relationship_profile_id_occurred_at_id_afacfa9a3b  (relationship_profile_id,occurred_at DESC,id)
#  index_interactions_on_relationship_profile_id             (relationship_profile_id)
#  index_interactions_on_unique_source                       (source_type,source_id) UNIQUE WHERE (source_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class Interaction < ApplicationRecord
  MANUAL_TYPES = %w[call message in_person video other].freeze
  DERIVED_TYPES = %w[conversation_recap mood_note].freeze
  TYPES = (MANUAL_TYPES + DERIVED_TYPES).freeze
  ORIGINS = %w[manual derived].freeze
  SOURCE_ATTRIBUTES = {
    "ConversationRecap" => { interaction_type: "conversation_recap", occurred_at: :occurred_at },
    "MoodNote" => { interaction_type: "mood_note", occurred_at: :observed_at }
  }.freeze

  belongs_to :relationship_profile
  belongs_to :source, polymorphic: true, optional: true

  normalizes :notes, with: ->(value) { value.to_s.strip.gsub(/[ \t]+/, " ").presence }

  validates :interaction_type, presence: true, inclusion: { in: TYPES }
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :occurred_at, presence: true
  validates :occurred_at, comparison: { less_than_or_equal_to: -> { Time.current } }, allow_nil: true
  validates :source_id, uniqueness: { scope: :source_type }, allow_nil: true
  validate :origin_matches_source
  validate :interaction_type_matches_origin
  validate :source_belongs_to_relationship_profile

  scope :ordered, -> { order(occurred_at: :desc, id: :asc) }

  def self.sync_from_source!(source)
    source_attributes = SOURCE_ATTRIBUTES.fetch(source.class.base_class.name)
    interaction = source.interaction || source.build_interaction(relationship_profile: source.relationship_profile)
    interaction.assign_attributes(
      interaction_type: source_attributes.fetch(:interaction_type),
      origin: "derived",
      occurred_at: source.public_send(source_attributes.fetch(:occurred_at)),
      notes: nil
    )
    interaction.save!
    interaction
  end

  def manual?
    origin == "manual"
  end

  def derived?
    origin == "derived"
  end

  def display_notes
    case source
    when ConversationRecap then source.body
    when MoodNote then source.observation
    else notes
    end
  end

  private

  def origin_matches_source
    if manual? && source.present?
      errors.add(:source, :manual_forbidden)
    elsif derived? && source.blank?
      errors.add(:source, :required)
    end
  end

  def interaction_type_matches_origin
    allowed_types = manual? ? MANUAL_TYPES : DERIVED_TYPES
    return if interaction_type.blank? || allowed_types.include?(interaction_type)

    errors.add(:interaction_type, :inclusion, value: interaction_type)
  end

  def source_belongs_to_relationship_profile
    return if source.blank? || relationship_profile_id.blank?
    return if source.respond_to?(:relationship_profile_id) && source.relationship_profile_id == relationship_profile_id

    errors.add(:source, :invalid)
  end
end
