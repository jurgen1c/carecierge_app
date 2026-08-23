# == Schema Information
#
# Table name: backup_plans
# Database name: primary
#
#  id                            :uuid             not null, primary key
#  event_plan_generation_version :bigint           not null
#  generated_at                  :datetime         not null
#  include_private_notes         :boolean          default(FALSE), not null
#  include_vault_context         :boolean          default(FALSE), not null
#  locale                        :string           default("en"), not null
#  lock_version                  :integer          default(0), not null
#  promoted_at                   :datetime
#  scenario                      :string           not null
#  source_context                :text             not null
#  status                        :string           default("generated"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  event_plan_id                 :uuid             not null
#  user_id                       :uuid             not null
#
# Indexes
#
#  index_backup_plans_on_event_plan_id          (event_plan_id)
#  index_backup_plans_on_plan_status_generated  (event_plan_id,status,generated_at)
#  index_backup_plans_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class BackupPlan < ApplicationRecord
  SCENARIOS = %w[
    weather vendor gift_delay restaurant_unavailable transportation illness_cancellation
  ].freeze
  STATUSES = %w[generated promoted superseded].freeze
  LOCALES = %w[en es].freeze
  MAX_SOURCES = 40
  MAX_SOURCE_LABEL_LENGTH = 240

  belongs_to :user
  belongs_to :event_plan
  has_many :backup_options, -> { ordered }, dependent: :destroy

  serialize :source_context, coder: JSON
  encrypts :source_context

  validates :scenario, inclusion: { in: SCENARIOS }
  validates :status, inclusion: { in: STATUSES }
  validates :locale, inclusion: { in: LOCALES }
  validates :generated_at, presence: true
  validates :context_fingerprint, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :event_plan_generation_version,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :event_plan_belongs_to_user
  validate :source_context_is_supported

  scope :recent_first, -> { order(generated_at: :desc, created_at: :desc, id: :desc) }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  private

  def event_plan_belongs_to_user
    return if user.blank? || event_plan.blank?
    return if event_plan.user_id == user_id

    errors.add(:event_plan, :owner_mismatch)
  end

  def source_context_is_supported
    valid = source_context.is_a?(Array) && source_context.present? &&
      source_context.length <= MAX_SOURCES && source_context.all? { |source| valid_source?(source) }
    errors.add(:source_context, :invalid) unless valid
  end

  def valid_source?(source)
    source.is_a?(Hash) &&
      source["id"].is_a?(String) && source["id"].present? &&
      source["label"].is_a?(String) && source["label"].present? &&
      source["label"].length <= MAX_SOURCE_LABEL_LENGTH &&
      source["certainty"].in?(%w[confirmed inferred]) &&
      [ true, false ].include?(source["sensitive"])
  end
end
