# == Schema Information
#
# Table name: feature_flag_assignments
# Database name: primary
#
#  id              :uuid             not null, primary key
#  enabled         :boolean          default(TRUE), not null
#  metadata        :jsonb            not null
#  target_kind     :string           not null
#  target_value    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  feature_flag_id :uuid             not null
#
# Indexes
#
#  index_feature_flag_assignments_on_feature_flag_id               (feature_flag_id)
#  index_feature_flag_assignments_on_flag_and_target               (feature_flag_id,target_kind,target_value) UNIQUE
#  index_feature_flag_assignments_on_target_kind_and_target_value  (target_kind,target_value)
#
# Foreign Keys
#
#  fk_rails_...  (feature_flag_id => feature_flags.id)
#
class FeatureFlagAssignment < ApplicationRecord
  TARGET_KINDS = %w[user account segment rollout_group environment global].freeze
  PRECEDENCE = TARGET_KINDS.each_with_index.to_h.freeze

  belongs_to :feature_flag

  normalizes :target_kind, with: ->(kind) { kind.to_s.strip.downcase }
  normalizes :target_value, with: ->(value) { value.to_s.strip }

  validates :target_kind, presence: true, inclusion: { in: TARGET_KINDS }
  validates :target_value, presence: true
  validates :target_value, uniqueness: { scope: [ :feature_flag_id, :target_kind ] }
  validate :global_target_value_is_all

  def matches?(context)
    context.value_for(target_kind) == target_value
  end

  def precedence
    PRECEDENCE.fetch(target_kind)
  end

  private

  def global_target_value_is_all
    return unless target_kind == "global"
    return if target_value == "all"

    errors.add(:target_value, :invalid, message: "must be all for global assignments")
  end
end
