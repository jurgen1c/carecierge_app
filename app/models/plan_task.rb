# == Schema Information
#
# Table name: plan_tasks
# Database name: primary
#
#  id               :uuid             not null, primary key
#  completed_at     :datetime
#  details          :text
#  due_on           :date
#  kind             :string           not null
#  lock_version     :integer          default(0), not null
#  origin           :string           default("manual"), not null
#  phase            :string           not null
#  position         :integer          not null
#  source_context   :text             not null
#  superseded_at    :datetime
#  title            :text             not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  backup_option_id :uuid
#  event_plan_id    :uuid             not null
#
# Indexes
#
#  index_plan_tasks_on_backup_option_id         (backup_option_id)
#  index_plan_tasks_on_event_plan_id            (event_plan_id)
#  index_plan_tasks_on_plan_and_superseded      (event_plan_id,superseded_at)
#  index_plan_tasks_on_plan_completion_and_due  (event_plan_id,completed_at,due_on)
#  index_plan_tasks_on_plan_phase_position      (event_plan_id,phase,position)
#
# Foreign Keys
#
#  fk_rails_...  (backup_option_id => backup_options.id) ON DELETE => nullify
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#
class PlanTask < ApplicationRecord
  PHASES = %w[decide arrange follow_through].freeze
  KINDS = %w[decision task reminder vendor_need gift_idea message_draft backup_step milestone].freeze
  ORIGINS = %w[manual template ai].freeze
  MAX_TITLE_LENGTH = 200
  MAX_DETAILS_LENGTH = 2_000
  MAX_SOURCES = 8

  belongs_to :event_plan
  belongs_to :backup_option, optional: true
  has_many :reminders, dependent: :nullify

  serialize :source_context, coder: JSON
  encrypts :title
  encrypts :details
  encrypts :source_context

  before_validation :normalize_fields

  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :details, length: { maximum: MAX_DETAILS_LENGTH }, allow_blank: true
  validates :phase, inclusion: { in: PHASES }
  validates :kind, inclusion: { in: KINDS }
  validates :origin, inclusion: { in: ORIGINS }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :source_context_is_supported

  scope :ordered, -> { order(:position, Arel.sql("due_on ASC NULLS LAST"), :created_at, :id) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :current, -> { where(superseded_at: nil) }

  def completed? = completed_at.present?
  def superseded? = superseded_at.present?

  def complete!(at: Time.current)
    event_plan.with_mutation_lock do
      with_lock do
        raise ActiveRecord::RecordNotFound if superseded?
        return if completed?

        update!(completed_at: at)
        reminders.active.find_each { |reminder| reminder.retire!(at:) }
        event_plan.increment!(:generation_version)
      end
    end
  end

  def reopen!
    event_plan.with_mutation_lock do
      with_lock do
        raise ActiveRecord::RecordNotFound if superseded?
        return unless completed?

        update!(completed_at: nil)
        event_plan.increment!(:generation_version)
      end
    end
  end

  private

  def normalize_fields
    self.title = title.to_s.squish
    self.details = details.to_s.strip.presence
    self.source_context ||= []
  end

  def source_context_is_supported
    valid = source_context.is_a?(Array) && source_context.length <= MAX_SOURCES && source_context.all? do |source|
      source.is_a?(Hash) && source["id"].is_a?(String) && source["label"].is_a?(String) &&
        source["certainty"].in?(%w[confirmed inferred]) && [ true, false ].include?(source["sensitive"])
    end
    errors.add(:source_context, :invalid) unless valid
  end
end
