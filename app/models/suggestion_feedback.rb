# == Schema Information
#
# Table name: suggestion_feedbacks
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  acted_at                :datetime
#  dismissed_at            :datetime
#  feedback                :string
#  fingerprint             :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_dismissed_at_d046df9002  (relationship_profile_id,dismissed_at)
#  index_suggestion_feedbacks_on_relationship_profile_id   (relationship_profile_id)
#  index_suggestion_feedbacks_on_user_id                   (user_id)
#  index_suggestion_feedbacks_on_user_id_and_fingerprint   (user_id,fingerprint) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class SuggestionFeedback < ApplicationRecord
  FEEDBACK_VALUES = %w[helpful not_for_me].freeze

  belongs_to :user
  belongs_to :relationship_profile

  normalizes :fingerprint, with: ->(value) { value.to_s.strip }

  validates :fingerprint, presence: true, length: { maximum: 128 }, uniqueness: { scope: :user_id }
  validates :feedback, inclusion: { in: FEEDBACK_VALUES }, allow_nil: true
  validate :relationship_profile_belongs_to_user

  def record_feedback!(value)
    update!(feedback: value)
  end

  def dismiss!
    update!(dismissed_at: Time.current)
  end

  def mark_acted!
    update!(acted_at: Time.current)
  end

  def hidden?
    dismissed_at.present? || acted_at.present? || feedback == "not_for_me"
  end

  private

  def relationship_profile_belongs_to_user
    return if user.blank? || relationship_profile.blank?
    return if relationship_profile.user_id == user_id

    errors.add(:relationship_profile, :invalid)
  end
end
