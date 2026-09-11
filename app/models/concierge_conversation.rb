# == Schema Information
#
# Table name: concierge_conversations
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  title                   :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_concierge_conversations_history                       (user_id,updated_at,id)
#  index_concierge_conversations_on_relationship_profile_id  (relationship_profile_id)
#  index_concierge_conversations_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id)
#
class ConciergeConversation < ApplicationRecord
  belongs_to :user
  belongs_to :relationship_profile, optional: true
  has_many :turns, class_name: "ConciergeTurn", foreign_key: :conversation_id, inverse_of: :conversation, dependent: :destroy

  encrypts :title

  validates :title, length: { maximum: 160 }
  validate :relationship_owned_by_user

  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  def context_available?
    relationship_profile_id.nil? || user.relationship_profiles.active.exists?(id: relationship_profile_id)
  end

  private

  def relationship_owned_by_user
    return if relationship_profile_id.nil?
    return if user && user.relationship_profiles.active.exists?(id: relationship_profile_id)

    errors.add(:relationship_profile, :invalid)
  end
end
