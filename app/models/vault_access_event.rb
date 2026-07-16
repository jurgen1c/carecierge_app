# == Schema Information
#
# Table name: vault_access_events
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  event_type              :string           not null
#  occurred_at             :datetime         not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  privacy_vault_item_id   :uuid
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_occurred_at_dc7b578e55  (relationship_profile_id,occurred_at)
#  index_vault_access_events_on_privacy_vault_item_id     (privacy_vault_item_id)
#  index_vault_access_events_on_relationship_profile_id   (relationship_profile_id)
#  index_vault_access_events_on_user_id                   (user_id)
#  index_vault_access_events_on_user_id_and_occurred_at   (user_id,occurred_at)
#
# Foreign Keys
#
#  fk_rails_...  (privacy_vault_item_id => privacy_vault_items.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class VaultAccessEvent < ApplicationRecord
  EVENT_TYPES = %w[
    unlock_failed unlocked locked viewed protected restored suggestion_usage_changed
  ].freeze

  belongs_to :user
  belongs_to :relationship_profile, optional: true
  belongs_to :privacy_vault_item, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, created_at: :desc) }

  def self.record!(event_type:, user:, relationship_profile:, privacy_vault_item: nil)
    create!(
      event_type:,
      user:,
      relationship_profile:,
      privacy_vault_item:,
      occurred_at: Time.current
    )
  end
end
