# == Schema Information
#
# Table name: mood_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string           not null
#  follow_up_at            :datetime
#  observation             :text             not null
#  observed_at             :datetime         not null
#  supportive_action       :text
#  timeline_visible        :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_mood_notes_on_relationship_profile_id                   (relationship_profile_id)
#  index_mood_notes_on_relationship_profile_id_and_category      (relationship_profile_id,category)
#  index_mood_notes_on_relationship_profile_id_and_follow_up_at  (relationship_profile_id,follow_up_at)
#  index_mood_notes_on_relationship_profile_id_and_observed_at   (relationship_profile_id,observed_at)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class MoodNote < ApplicationRecord
  CATEGORIES = %w[stressed distant excited sad overwhelmed proud other].freeze

  belongs_to :relationship_profile
  has_one :timeline_entry, as: :source_record, dependent: :destroy

  before_validation :default_observed_at
  before_validation :normalize_text_fields

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :observation, presence: true
  validates :observed_at, presence: true

  scope :ordered, -> { order(observed_at: :desc, category: :asc, id: :asc) }

  def display_title
    observation.to_s.squish.truncate(80)
  end

  def category_label
    self.class.category_label(category)
  end

  def self.category_options
    CATEGORIES.map { |value| [ category_label(value), value ] }
  end

  def self.category_label(value)
    I18n.t("mood_notes.categories.#{value}")
  end

  private

  def default_observed_at
    self.observed_at ||= Time.current if new_record?
  end

  def normalize_text_fields
    self.observation = observation.to_s.strip
    self.supportive_action = supportive_action.to_s.strip.presence
  end
end
