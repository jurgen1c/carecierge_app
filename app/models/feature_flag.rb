# == Schema Information
#
# Table name: feature_flags
# Database name: primary
#
#  id          :uuid             not null, primary key
#  description :text
#  enabled     :boolean          default(FALSE), not null
#  key         :string           not null
#  metadata    :jsonb            not null
#  name        :string           not null
#  retired_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_feature_flags_on_key         (key) UNIQUE
#  index_feature_flags_on_retired_at  (retired_at)
#
class FeatureFlag < ApplicationRecord
  has_many :feature_flag_assignments, dependent: :destroy
  has_many :feature_flag_audit_events, dependent: :destroy

  normalizes :key, with: ->(key) { key.to_s.strip.downcase }

  validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :name, presence: true

  scope :active, -> { where(retired_at: nil) }
  scope :retired, -> { where.not(retired_at: nil) }
  scope :ordered, -> { order(:key) }

  def self.enabled?(key, **context)
    includes(:feature_flag_assignments).find_by(key: key.to_s.strip.downcase)&.enabled_for?(**context) || false
  end

  def enabled_for?(**context)
    return false if retired?

    flag_context = FeatureFlags::Context.new(**context)
    assignment = feature_flag_assignments.sort_by(&:precedence).detect { |candidate| candidate.matches?(flag_context) }

    assignment ? assignment.enabled? : enabled?
  end

  def retired?
    retired_at.present?
  end
end
