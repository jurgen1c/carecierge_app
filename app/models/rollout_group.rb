# == Schema Information
#
# Table name: rollout_groups
# Database name: primary
#
#  id          :uuid             not null, primary key
#  criteria    :jsonb            not null
#  description :text
#  key         :string           not null
#  name        :string           not null
#  retired_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_rollout_groups_on_key         (key) UNIQUE
#  index_rollout_groups_on_retired_at  (retired_at)
#
class RolloutGroup < ApplicationRecord
  normalizes :key, with: ->(key) { key.to_s.strip.downcase }

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :name, presence: true

  scope :active, -> { where(retired_at: nil) }
  scope :retired, -> { where.not(retired_at: nil) }
  scope :ordered, -> { order(:key) }

  def retired?
    retired_at.present?
  end
end
