# == Schema Information
#
# Table name: backup_options
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  change_summary        :text             not null
#  cost_level            :string           not null
#  effort                :string           not null
#  estimated_cost_cents  :integer
#  lock_version          :integer          default(0), not null
#  position              :integer          not null
#  preserved_constraints :text             not null
#  promoted_at           :datetime
#  relationship_fit      :string           not null
#  replacement_task_ids  :text             not null
#  reviewed_reminders    :text             not null
#  source_context        :text             not null
#  summary               :text             not null
#  task_blueprints       :text             not null
#  timing                :string           not null
#  title                 :text             not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  backup_plan_id        :uuid             not null
#
# Indexes
#
#  index_backup_options_on_backup_plan_id               (backup_plan_id)
#  index_backup_options_on_backup_plan_id_and_position  (backup_plan_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (backup_plan_id => backup_plans.id) ON DELETE => cascade
#
class BackupOption < ApplicationRecord
  EFFORTS = %w[low medium high].freeze
  TIMINGS = %w[same_day within_week new_date].freeze
  COST_LEVELS = %w[lower similar higher unknown].freeze
  RELATIONSHIP_FITS = %w[strong good fair].freeze
  MAX_TITLE_LENGTH = 200
  MAX_SUMMARY_LENGTH = 1_000
  MAX_LIST_ITEMS = 8
  MAX_LIST_ITEM_LENGTH = 300
  MAX_TASKS = 8
  MAX_SOURCES = 8
  MAX_REVIEWED_REMINDERS = 40
  REVIEWED_REMINDER_KEYS = %w[
    id plan_task_id title scheduled_at snoozed_until time_zone recurrence reminder_type priority
  ].freeze

  belongs_to :backup_plan
  has_many :plan_tasks, dependent: :nullify

  serialize :preserved_constraints, coder: JSON
  serialize :change_summary, coder: JSON
  serialize :task_blueprints, coder: JSON
  serialize :replacement_task_ids, coder: JSON
  serialize :reviewed_reminders, coder: JSON
  serialize :source_context, coder: JSON

  encrypts :title
  encrypts :summary
  encrypts :preserved_constraints
  encrypts :change_summary
  encrypts :task_blueprints
  encrypts :reviewed_reminders
  encrypts :source_context

  before_validation :normalize_fields

  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :summary, presence: true, length: { maximum: MAX_SUMMARY_LENGTH }
  validates :effort, inclusion: { in: EFFORTS }
  validates :timing, inclusion: { in: TIMINGS }
  validates :cost_level, inclusion: { in: COST_LEVELS }
  validates :relationship_fit, inclusion: { in: RELATIONSHIP_FITS }
  validates :estimated_cost_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: EventPlan::MAX_BUDGET_CENTS },
    allow_nil: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :structured_fields_are_supported

  def self.reminder_snapshot(reminder)
    {
      "id" => reminder.id,
      "plan_task_id" => reminder.plan_task_id,
      "title" => reminder.title,
      "scheduled_at" => reminder.scheduled_at.iso8601(6),
      "snoozed_until" => reminder.snoozed_until&.iso8601(6),
      "time_zone" => reminder.time_zone,
      "recurrence" => reminder.recurrence,
      "reminder_type" => reminder.reminder_type,
      "priority" => reminder.priority
    }
  end

  scope :ordered, -> { order(:position, :created_at, :id) }

  private

  def normalize_fields
    self.title = title.to_s.squish
    self.summary = summary.to_s.squish
    self.preserved_constraints ||= []
    self.change_summary ||= []
    self.task_blueprints ||= []
    self.replacement_task_ids ||= []
    self.reviewed_reminders ||= []
    self.source_context ||= []
  end

  def structured_fields_are_supported
    errors.add(:preserved_constraints, :invalid) unless valid_text_list?(preserved_constraints)
    errors.add(:change_summary, :invalid) unless valid_text_list?(change_summary)
    errors.add(:replacement_task_ids, :invalid) unless valid_replacement_ids?
    errors.add(:reviewed_reminders, :invalid) unless valid_reviewed_reminders?
    errors.add(:task_blueprints, :invalid) unless valid_task_blueprints?
    errors.add(:source_context, :invalid) unless valid_sources?(source_context, required: true)
  end

  def valid_text_list?(value)
    value.is_a?(Array) && value.present? && value.length <= MAX_LIST_ITEMS &&
      value.all? { |item| item.is_a?(String) && item.present? && item.length <= MAX_LIST_ITEM_LENGTH }
  end

  def valid_replacement_ids?
    replacement_task_ids.is_a?(Array) && replacement_task_ids.length <= MAX_TASKS &&
      replacement_task_ids.all? { |id| id.is_a?(String) && id.present? }
  end

  def valid_task_blueprints?
    task_blueprints.is_a?(Array) && task_blueprints.present? && task_blueprints.length <= MAX_TASKS &&
      task_blueprints.all? do |task|
        task.is_a?(Hash) && task["phase"].in?(PlanTask::PHASES) && task["kind"].in?(PlanTask::KINDS) &&
          task["title"].is_a?(String) && task["title"].present? && task["title"].length <= PlanTask::MAX_TITLE_LENGTH &&
          (task["details"].nil? || task["details"].is_a?(String) && task["details"].length <= PlanTask::MAX_DETAILS_LENGTH) &&
          valid_due_on?(task["due_on"]) && valid_sources?(task["source_context"], required: true)
      end
  end

  def valid_reviewed_reminders?
    reviewed_reminders.is_a?(Array) && reviewed_reminders.length <= MAX_REVIEWED_REMINDERS &&
      reviewed_reminders.all? do |reminder|
        reminder.is_a?(Hash) && reminder.keys.sort == REVIEWED_REMINDER_KEYS.sort &&
          reminder["id"].is_a?(String) && reminder["id"].present? &&
          reminder["plan_task_id"].is_a?(String) && reminder["plan_task_id"].present? &&
          reminder["title"].is_a?(String) && reminder["title"].present? &&
          valid_timestamp?(reminder["scheduled_at"]) &&
          (reminder["snoozed_until"].nil? || valid_timestamp?(reminder["snoozed_until"])) &&
          ActiveSupport::TimeZone[reminder["time_zone"]].present? &&
          reminder["recurrence"].in?(Reminder::RECURRENCES) &&
          reminder["reminder_type"].in?(Reminder::REMINDER_TYPES) &&
          reminder["priority"].in?(Reminder::PRIORITIES)
      end
  end

  def valid_due_on?(value)
    return true if value.nil?

    Date.iso8601(value.to_s)
    true
  rescue Date::Error
    false
  end

  def valid_timestamp?(value)
    Time.iso8601(value.to_s)
    true
  rescue ArgumentError
    false
  end

  def valid_sources?(value, required:)
    value.is_a?(Array) && (!required || value.present?) && value.length <= MAX_SOURCES && value.all? do |source|
      source.is_a?(Hash) && source["id"].is_a?(String) && source["id"].present? &&
        source["label"].is_a?(String) && source["label"].present? &&
        source["certainty"].in?(%w[confirmed inferred]) && [ true, false ].include?(source["sensitive"])
    end
  end
end
